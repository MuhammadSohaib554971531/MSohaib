// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;//Q1

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CustomToken is ERC20, Ownable {
    uint256 public constant MAX_SUPPLY = 1_000_000 * 10**18; // 10 lakh tokens with 18 decimals
    
    constructor(address initialOwner) 
        ERC20("ReferralToken", "RFT") 
        Ownable(initialOwner) 
    {
        _mint(initialOwner, MAX_SUPPLY); // Mint all tokens to owner initially
    }

    function mint(address to, uint256 amount) external onlyOwner {
        require(totalSupply() + amount <= MAX_SUPPLY, "CustomToken: max supply exceeded");
        _mint(to, amount);
    }
}