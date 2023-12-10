// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

//import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./interfaces/ISimpleP2PLoanTerm.sol";
import "hardhat/console.sol";


//At First, create simple P2P loan Term. This contract does not support cross chain but simply works on a single chain
//TODO must implement {IERC721Receiver-onERC721Received} to accept collateral NFT
contract SimpleP2PLoanTerm is ISimpleP2PLoanTerm
{
    using SafeERC20 for IERC20Metadata;

    uint256 public constant SECONDS_IN_A_HOUR = 3600;
    uint256 public constant SECONDS_IN_A_DAY = 86400;
    uint256 public constant SECONDS_IN_A_WEEK = 604800;
    uint256 public constant SECONDS_IN_A_YEAR = 31449600;
    uint256 public constant DENOMINATOR = 10000;


    /* ========== STATE VARIABLES ========== */
    IERC20Metadata public token;//loan token
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
    LoanStatus public status;
    NFT public collateral;//TODO currently only support one NFT collateral. Multi-NFT collateral can be achieved by making this field as array.

    /* ========== CONSTRUCTOR ========== */


    constructor(
        address _token,
        uint256 _totalAmount,
        uint256 _maturityPeriod,
        uint64 _interestRate,
        address _borrower,
        address _lender,
        address _admin,
        LoanStatus _status
    ) {
        require(_totalAmount > 0, "amount of loan should be positive");
        token = IERC20Metadata(_token);
        totalAmount = _totalAmount;
        maturityPeriod = _maturityPeriod;
        interestRate = _interestRate;
        borrower = _borrower;
        lender = _lender;
        admin = _admin;
        status = _status;
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
        //TODO better to support partial amount of lend in the future.
        require(status == LoanStatus.Activated, "cannot loan in current status");
        //in case the lender did twice, nothing will be deposited
        token.safeTransferFrom(msg.sender, address(this), totalAmount - principal);
        principal = totalAmount;
        emit Lend(msg.sender, principal);
    }


    function loanTransfer(address beneficiary) external onlyLender  {
        lender = beneficiary;
        emit TransferLoan(msg.sender, beneficiary);
    }

    function claimInterest() public override onlyLender
    {
        //when status is Redeemed, use claimPrincipal. claimInterest will be performed altogether
        require (status == LoanStatus.Started, "Not the status user can claim the interest");
        _claimInterest();
    }

    //this function is called through claimInterest by lender (payer: borrower, receiver: lender)
    // claimPrincipal by lender (payer: this contract, receiver: lender) will be handled separatelly
    function _claimInterest() internal
    {
        uint256 claimableAmount = claimableInterest();
        if (claimableAmount > 0) {
            claimedInterest += claimableAmount;
            try token.transferFrom(borrower, msg.sender, claimableAmount) {//directly take interest from borrower's wallet through this contract.
                paidInterest += claimableAmount; //paid amount of borrower is updated.
                emit ClaimInterest(borrower, msg.sender, claimableAmount);
            } catch {
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
    function claimPrincipal() external onlyLender {

        if (block.timestamp < maturityTime) { //This is called during the working status when partial redeem is happened
            require(status == LoanStatus.Started, "The Loan is not started yet");
            _withdrawPrincipal();
            _claimInterest();

        } else if (status == LoanStatus.Redeemed){ //block.timestamp >= maturityTime and redemption is completed
            _withdrawPrincipal();
            //_claimInterest(address(this));
            if (status != LoanStatus.Defaulted){ //if _claimInterest is failed for some reason, keep status default and should not change "completed"
                status = LoanStatus.Completed;
            }
        } else { //block.timestamp >= maturityTime and redemption is not completed i.e. delayed
            //collected all redeemed money in this contract.
            _withdrawPrincipal();
            //try to collect the rest of principal directly from borrower as maturityTime is already expired.
            uint256 amount = totalAmount - claimedPrincipal;
            try token.transferFrom(borrower, msg.sender, amount) {
                emit ClaimPrincipal(borrower, msg.sender, amount);
                //if principal collection is succeeded, then try to collect interest in the same way.
                _claimInterest();

            } catch {
                status = LoanStatus.Defaulted;
                emit DefaultLoan();
            }

        }

    }


    function _withdrawPrincipal() internal {
        uint256 amount = withdrawablePrincipal();
        if (amount>0) {
            token.safeTransfer(msg.sender, amount);
            claimedPrincipal += amount;
            emit ClaimPrincipal(address(this), msg.sender, amount);
        }
        // in case redeemed in full, interest should be collected from this address.
        // this is special case. otherwise, call _claimInterest function and collect from borrower
        if(status == LoanStatus.Redeemed) {
            uint256 claimableAmount = claimableInterest();
            if (claimableAmount > 0) {
                claimedInterest += claimableAmount;
                try token.transfer(msg.sender, claimableAmount) {//directly take interest from borrower's wallet through this contract.
                    emit ClaimInterest(borrower, msg.sender, claimableAmount);
                } catch {
                    status = LoanStatus.Defaulted;
                    emit DefaultLoan();
                }
            }
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

    function cancelBorrowing() external onlyBorrower {
        require(status == LoanStatus.Activated, "borrower can cancel only before the loan starts");
        _withdrawCollateral(borrower);
        if (principal > 0){
            token.safeTransfer(lender, principal);
        }
        status = LoanStatus.Cancelled;
        emit CancelLoan();

    }

    function startBorrowing() external onlyBorrower {
        require(status == LoanStatus.Activated, "not the status borrower can start");
        require(principal != 0, "Lender does not offer the fund yet");
        initiatedTime = block.timestamp;
        maturityTime = block.timestamp + maturityPeriod;
        lastCheckTime = initiatedTime;
        status = LoanStatus.Started;
        token.safeTransfer(borrower, principal);
        emit StartLoan();
    }


    function redeemFullPrincipal() external onlyBorrower {
        require(status == LoanStatus.Started, "loan term has not started yet");
        uint256 amount = currentPrincipal();
        token.transferFrom(msg.sender, address(this), amount);
        _checkAccruedInterest(); //need to execute this before redeemedAmount is updated. because currentPrincipal() will be changed.
        redeemedAmount += amount;
        status = LoanStatus.Redeemed;
        //since collateral will be withdrawn, borrower needs to pay the rest of accrued interest at once.
        _redeemInterest();

        if(block.timestamp < maturityTime) {
            maturityTime = block.timestamp; //for early redemption, needs to stop accruing interest at this point
        }
        emit RedeemPrincipal(msg.sender, amount);

        require(status == LoanStatus.Redeemed, "loan is not redeemed yet");
        _withdrawCollateral(borrower);
    }

    function _redeemInterest() internal {
        require(status == LoanStatus.Redeemed, "only process when principal was fully redeemed");
        uint256 amount = accruedInterest() - paidInterest;
        token.transferFrom(msg.sender, address(this), amount);
        paidInterest += amount;

        emit RedeemInterest(msg.sender, amount);

    }

    function redeemPartialPrincipal(uint256 amount) external onlyBorrower {
        require(status == LoanStatus.Started, "loan term has not started yet");
        require(amount < currentPrincipal(), "amount should be less than principal");
        token.transferFrom(msg.sender, address(this), amount);
        _checkAccruedInterest(); //need to execute this before redeemedAmount is updated. because currentPrincipal() will be changed.
        redeemedAmount += amount;
        emit RedeemPrincipal(msg.sender, totalAmount);

    }

    function _checkAccruedInterest() internal {
        lastCheckAccruedInterest = accruedInterest();//need to set lastCheckAccruedInterest before updating lastCheckTime
        lastCheckTime = block.timestamp;

    }


    function _withdrawCollateral(address receiver) internal {

        IERC721(collateral.owner).safeTransferFrom(address(this), receiver, collateral.tokenId);
        collateral.owner = address(0);
        emit WithdrawCollateral(receiver, collateral.owner, collateral.tokenId);
    }

    /* ========== Admin FUNCTIONS ========== */
    function liquidateCollateral() external onlyAdmin {
        require(status == LoanStatus.Defaulted, "The loan is not default");

        _withdrawCollateral(admin);
        emit LiquidateCollateral(borrower, collateral.owner, collateral.tokenId);
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

}
