// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;


import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./interfaces/IXRPBridgeLoanTerm.sol";
import "./interfaces/IWXRP.sol";
import "./interfaces/IBridgeDoorNative.sol";
import "hardhat/console.sol";


contract XRPBridgeLoanTerm is IXRPBridgeLoanTerm
{
    using SafeERC20 for IWXRP;

    uint256 public constant SECONDS_IN_A_HOUR = 3600;
    uint256 public constant SECONDS_IN_A_DAY = 86400;
    uint256 public constant SECONDS_IN_A_WEEK = 604800;
    uint256 public constant SECONDS_IN_A_YEAR = 31449600;
    uint256 public constant DENOMINATOR = 10000;
    uint256 public signatureReward = 1 ether;


    /* ========== STATE VARIABLES ========== */
    IWXRP public token;//wxrp token
    uint64 public interestRate;// 10000 = 100%
    uint256 public maturityPeriod;

    uint256 public initiatedTime; //TO be set when starting the loan. unchange once it is set for the record purpose.
    uint256 public maturityTime; //To be set when starting the loan
    uint256 public lastCheckTime; //the last time interest amount is calculated. this is updated when redeemed principal in part or full.

    uint256 public totalAmount;//the total amount borrower would like to borrow
    uint256 public redeemedAmount;
    uint256 public paidInterest;//paid interest by borrower
    uint256 public principal;//amount of loan the lender offers
    uint256 public claimedPrincipal;
    uint256 public claimedInterest;//claimed interest amount of the lender
    uint256 public lastCheckAccruedInterest;//claimed interest amount of the lender. this is updated when redeemed principal in part or full.

    address public borrower;//the account of borrower
    address public lender;//the account of lender
    address public admin;//the account of platform admin
    address public borrowerXRP;
    address public lenderXRP;
    LoanStatus public status;
    NFT public collateral;//TODO currently only support one NFT collateral. Multi-NFT collateral can be achieved by making this field as array.

    IBridgeDoorNative public brideDoor;

    /* ========== CONSTRUCTOR ========== */


    constructor(
        address _token,
        uint256 _totalAmount,
        uint256 _maturityPeriod,
        uint64 _interestRate,
        address _borrower,
        address _lender,
        address _lenderXRP,
        address _borrowerXRP,
        address _bridgeDoor
    ) {
        require(_totalAmount > 0, "amount of loan should be positive");
        token = IWXRP(_token);
        totalAmount = _totalAmount;
        maturityPeriod = _maturityPeriod;
        interestRate = _interestRate;
        borrower = _borrower;
        lender = _lender;
        admin = msg.sender;
        borrowerXRP = _borrowerXRP;
        lenderXRP = _lenderXRP;
        status = LoanStatus.Created;
        brideDoor = IBridgeDoorNative(_bridgeDoor);
        redeemedAmount = 0;
        paidInterest = 0;
        principal = 0;
        claimedInterest = 0;
        lastCheckAccruedInterest = 0;
    }

    /* ========== VIEWS ========== */

    function currentPrincipal() public view override returns (uint256) {
        return totalAmount - redeemedAmount;
    }

    function accruedInterest() public view override returns (uint256) {
        uint256 latestTime = Math.min(maturityTime, block.timestamp);
        // (latestTime - lastCheckTime) / SECONDS_IN_A_YEAR) * (interestRate / DENOMINATOR)
        // * currentPrincipal() + lastCheckAccruedInterest
        // change the calculate order in order to prevent some value is rounded to 0 in process.
        uint256 amount = (latestTime - lastCheckTime) * currentPrincipal() * interestRate / (SECONDS_IN_A_YEAR * DENOMINATOR)
                            + lastCheckAccruedInterest;
        return amount;
    }

    function claimableInterest() public view override returns (uint256) {
        return accruedInterest() - claimedInterest;
    }

    function withdrawablePrincipal() public view override returns (uint256) {
        return redeemedAmount - claimedPrincipal;
    }


    /* ========== Lender FUNCTIONS ========== */
    function lend() external override onlyLender
    {
        require(status == LoanStatus.Activated, "cannot loan in current status");
        uint256 claimId = brideDoor.createClaimId{value: signatureReward}(lender);
        emit CreateClaimId(claimId);
        //deposit process will be done in receive() function
        //TODO: Consider support claim() function in this contract for the case payment has not processed automatically
    }


    function loanTransfer(address beneficiary) external onlyLender  {
        lender = beneficiary;
        emit TransferLoan(msg.sender, beneficiary);
    }

    function claimInterest(uint256 claimId) public override onlyLender
    {
        //when status is Redeemed, use claimPrincipal. claimInterest will be performed altogether
        require (status == LoanStatus.Started || status == LoanStatus.Redeemed, "Not the status user can claim the interest");
        uint256 claimableAmount = claimableInterest();
        if (claimableAmount > 0) {


            if (address(this).balance >= claimableAmount) {
                brideDoor.commit{value: claimableAmount + signatureReward}(lenderXRP, claimId, claimableAmount);
                claimedInterest += claimableAmount;
                emit ClaimInterest(msg.sender, claimId, claimableAmount);
                if (status == LoanStatus.Redeemed && claimableInterest()==0 && withdrawablePrincipal()==0){
                    status = LoanStatus.Completed;
                }
            } else {
                brideDoor.commit{value: claimableAmount + signatureReward}(lenderXRP, claimId, address(this).balance);
                claimedInterest += address(this).balance;
                status = LoanStatus.Defaulted;
                emit DefaultLoan();
            }

        }
    }

    function approveLoanTerm() external onlyLender {
        require(status == LoanStatus.Created, "already approved");
        status = LoanStatus.Activated;
        emit ApproveLoanTerm();
    }



    //This function is called
    //1. after when borrower made a partial redemption
    //2. after when borrower made a full redemption
    //3. after maturity period (not sure if all liability are fully redeemed or not by borrower)
    function claimPrincipal(uint256 claimId) external onlyLender {

        if (block.timestamp < maturityTime) { //This is called during the working status when partial redeem is happened
            require(status == LoanStatus.Started, "The Loan is not started yet");
            _withdrawPrincipal(claimId);

        } else if (status == LoanStatus.Redeemed){ //block.timestamp >= maturityTime and redemption is completed
            _withdrawPrincipal(claimId);
            if (claimableInterest()==0 && withdrawablePrincipal()==0){
                status = LoanStatus.Completed;
            }
        } else { //block.timestamp >= maturityTime and redemption is not completed i.e. delayed
            //collected all redeemed money in this contract.
            _withdrawPrincipal(claimId);
            if (currentPrincipal() > 0){
                status = LoanStatus.Defaulted;
                emit DefaultLoan();
            }

        }

    }


    function _withdrawPrincipal(uint256 claimId) internal {
        uint256 amount = withdrawablePrincipal();
        if (amount>0) {
            brideDoor.commit{value: amount + signatureReward}(lenderXRP, claimId, amount);
            claimedPrincipal += amount;
            emit ClaimPrincipal(msg.sender, claimId, amount);//chainge interface
        }
    }


    /* ========== Borrower FUNCTIONS ========== */
    function depositNFTCollateral(address owner, uint256 tokenId) external onlyBorrower {
        require(collateral.owner == address(0), "collateral is already deposited");
        IERC721(owner).transferFrom(msg.sender, address(this), tokenId);
        collateral.owner = owner;
        collateral.tokenId = tokenId;
        emit DepositCollateral(owner, tokenId);
    }

    function cancelBorrowing(uint256 claimId) external onlyBorrower {
        require(status == LoanStatus.Activated, "borrower can cancel only before the loan starts");

        brideDoor.commit{value: principal + signatureReward}(borrowerXRP, claimId, principal);
        status = LoanStatus.Cancelled;
        emit CancelLoan();

    }

    function startBorrowing(uint256 claimId) external onlyBorrower {
        require(status == LoanStatus.Activated, "not the status borrower can start");
        require(principal != 0, "Lender does not offer the fund yet");
        initiatedTime = block.timestamp;
        maturityTime = block.timestamp + maturityPeriod;
        lastCheckTime = initiatedTime;
        status = LoanStatus.Started;
        brideDoor.commit{value: totalAmount + signatureReward}(borrowerXRP, claimId, totalAmount);
        emit StartLoan();
    }


    function redeemPrincipal() external onlyBorrower {
        require(status == LoanStatus.Started, "loan term has not started yet");
        uint256 amount = currentPrincipal();
        if (amount>0){
            uint256 claimId = brideDoor.createClaimId{value: signatureReward}(borrower);
            emit CreateClaimId(claimId);
            status = LoanStatus.PrincipalRedeeming;
        }

    }

    function redeemInterest() external onlyBorrower {
        require(status == LoanStatus.Started || (status == LoanStatus.Redeemed && (accruedInterest() - paidInterest) > 0), "not the status to redeem interest");
        uint256 amount = accruedInterest() - paidInterest;
        if (amount>0){
            uint256 claimId = brideDoor.createClaimId{value: signatureReward}(borrower);
            emit CreateClaimId(claimId);
        }

    }



    function _checkAccruedInterest() internal {
        lastCheckAccruedInterest = accruedInterest();//need to set lastCheckAccruedInterest before updating lastCheckTime
        lastCheckTime = block.timestamp;
    }


    function withdrawCollateral() external onlyBorrower {
        if(status == LoanStatus.Redeemed || status == LoanStatus.Cancelled) {
            IERC721(collateral.owner).transferFrom(address(this), borrower, collateral.tokenId);
             emit WithdrawCollateral(borrower, collateral.owner, collateral.tokenId);
            collateral.owner = address(0);
        }
    }

    /* ========== Admin FUNCTIONS ========== */
    function liquidateCollateral() external onlyAdmin {
        require(status == LoanStatus.Defaulted, "The loan is not default");

        IERC721(collateral.owner).transferFrom(address(this), admin, collateral.tokenId);
        emit LiquidateCollateral(borrower, collateral.owner, collateral.tokenId);
        collateral.owner = address(0);
    }

    /* ========== MODIFIERS ========== */
    modifier onlyBorrower() {
        require(msg.sender == borrower, "not borrower");
        _;
    }

    modifier onlyLender() {
        require(msg.sender == lender, "not lender");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "not admin");
        _;
    }

    receive() external payable {
        if (status == LoanStatus.Created) {
            emit InitialDeposit(msg.sender, msg.value);
        } else if(status == LoanStatus.Activated){
            //TODO check that msg.sender should be gnosis multisig account of BridgeDoorNative
            principal += msg.value;
            emit Lend(msg.sender, principal);
        } else if (status == LoanStatus.Started || (status == LoanStatus.Redeemed && (accruedInterest() - paidInterest) > 0)) {
            _checkAccruedInterest();
            paidInterest += msg.value;
            emit RedeemInterest(msg.sender, msg.value);
        } else if (status == LoanStatus.PrincipalRedeeming) {
            _checkAccruedInterest(); //need to execute this before redeemedAmount is updated. because currentPrincipal() will be changed.
            redeemedAmount += msg.value;
            if (currentPrincipal()==0) {
                status = LoanStatus.Redeemed;
                if(block.timestamp < maturityTime) {
                    maturityTime = block.timestamp; //for early redemption, needs to stop accruing interest at this point
                }
            } else {
                status = LoanStatus.Started;
            }
            emit RedeemPrincipal(msg.sender, msg.value);

        } else { 
            //TODO: emit warning event for unexpected deposit
        }
    }

}
