// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface ISimpleP2PLoanTerm {

    enum LoanStatus {
        Created,  //initial term creation
        Activated,  //collateral is deposited
        Started, //lenders offered target amount and ready to borrow
        Redeemed, //borrower complete redemption of loan
        Completed, // all lender has collected their principal and eligible interest
        Cancelled, //loan was not executed and canceled
        Defaulted //borrower failed to repay either interest at every 4 weeks or principal at maturity date
    }

    struct NFT {
        address owner;
        uint256 tokenId;
    }


    /* ========== EVENTS ========== */
    event Lend(address indexed lender, uint256 principal);
    event ClaimPrincipal(address from, address indexed lender, uint256 amount);
    event ClaimInterest(address indexed from, address lender, uint256 amount);
    event DefaultLoan();
    event ApproveLoanTerm();
    event DepositCollateral(address indexed owner, uint256 tokenId);
    event StartLoan();
    event RedeemPrincipal(address indexed borrower, uint256 amount);
    event RedeemInterest(address indexed borrower, uint256 amount);
    event WithdrawCollateral(address indexed receiver, address owner, uint256 tokenId);
    event TransferLoan(address indexed lender, address beneficiary);
    event CancelLoan();
    event LiquidateCollateral(address indexed borrower, address indexed owner, uint256 tokenId);

    /* ========== VIEWS ========== */
    function currentPrincipal() external view returns (uint256);
    function accruedInterest() external view returns (uint256);
    function claimableInterest() external view returns (uint256);
    function withdrawablePrincipal() external view returns (uint256);

    /* ========== Lender FUNCTIONS ========== */
    function lend() external;
    function loanTransfer(address beneficiary) external;
    function claimInterest() external;
    function approveLoanTerm() external;
    function claimPrincipal() external;

    /* ========== Borrower FUNCTIONS ========== */
    function depositNFTCollateral(address owner, uint256 tokenId) external;
    function cancelBorrowing() external;
    function startBorrowing() external;
    function redeemFullPrincipal() external;
    function redeemPartialPrincipal(uint256 amount) external;

    /* ========== Admin FUNCTIONS ========== */
    function liquidateCollateral() external;
}
