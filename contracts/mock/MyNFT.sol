// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyNFT is ERC721, Ownable {
    uint256 public nextTokenId;

    constructor()
    ERC721("MyNFT", "MNFT")
    Ownable(msg.sender)
    {
        //safeMint(msg.sender);
    }

    function safeMint(address to) public onlyOwner {
        uint256 tokenId = nextTokenId++;
        _safeMint(to, tokenId);
    }
}
