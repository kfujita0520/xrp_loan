// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract USDToken is ERC20, Ownable {
    constructor(uint256 initialSupply) ERC20("USD Token", "USD") Ownable(msg.sender) {
        _mint(msg.sender, initialSupply);
        //_mint(msg.sender, 1000000 * 10**18);
    }

    function mint(uint256 amount) external onlyOwner {
        _mint(msg.sender, amount);
    }
}
