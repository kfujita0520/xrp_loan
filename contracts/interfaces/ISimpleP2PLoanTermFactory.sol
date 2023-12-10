// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ISimpleP2PLoanTerm.sol";

interface ISimpleP2PLoanTermFactory {

    event CreateP2PLoanTerm(
        address indexed token,
        uint256 totalAmount,
        uint256 maturityPeriod,
        uint64 interestRate,
        address indexed borrower,
        address indexed lender,
        address admin
    );

    function createLoanTerm(
        address token,
        uint256 totalAmount,
        uint256 maturityPeriod,
        uint64 interestRate,
        address borrower,
        address lender
    ) external returns(uint index);

    function getSimpleP2PLoanTerm(uint index) external view returns (ISimpleP2PLoanTerm);
}
