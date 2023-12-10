// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "@openzeppelin/contracts/access/Ownable.sol";
import "./SimpleP2PLoanTerm.sol";
import "./interfaces/ISimpleP2PLoanTerm.sol";
import "./interfaces/ISimpleP2PLoanTermFactory.sol";

contract SimpleP2PLoanTermFactory is Ownable, ISimpleP2PLoanTermFactory {

    address public admin;
    ISimpleP2PLoanTerm[] public loanTerms;

    constructor() Ownable(msg.sender) {
        admin = msg.sender;
    }

    function createLoanTerm(
        address _token,
        uint256 _totalAmount,
        uint256 _maturityPeriod,
        uint64 _interestRate,
        address _borrower,
        address _lender
    ) public returns(uint index){
        SimpleP2PLoanTerm loanTerm = new SimpleP2PLoanTerm(
            _token,
            _totalAmount,
            _maturityPeriod,
            _interestRate,
            _borrower,
            _lender,
            admin,
            ISimpleP2PLoanTerm.LoanStatus.Created
        );
        loanTerms.push(loanTerm);
        emit CreateP2PLoanTerm(_token, _totalAmount, _maturityPeriod, _interestRate, _borrower, _lender, admin);
        return loanTerms.length - 1;
    }

    function getSimpleP2PLoanTerm(uint index) public view returns (ISimpleP2PLoanTerm) {
        return loanTerms[index];
    }

    function getLoanTermsLength() public view returns (uint256) {
        return loanTerms.length;
    }

}
