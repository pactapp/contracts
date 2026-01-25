// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Owned} from "solmate/auth/Owned.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Bank is Owned {
    address public usdc;

    uint256 public totalShares;

    uint256 public constant penalty = 10_00; // 10%
    uint256 public constant protocolFee = 10_00; // 10% on penalty withdraws, total 1% of withdraw amount

    mapping(address => uint256) public shares;

    constructor(address _usdc) Owned(owner) {
        owner = msg.sender;
        usdc = _usdc;
    }

    function deposit(uint256 amount) public {
        require(amount > 0, "Deposit must be more than 0");

        uint256 assetsBefore = IERC20(usdc).balanceOf(address(this));

        IERC20(usdc).transferFrom(msg.sender, address(this), amount);

        uint256 sharesAlloted;

        if (totalShares == 0) {
            sharesAlloted = amount;
        } else {
            sharesAlloted = amount * totalShares / assetsBefore;
        }

        totalShares += sharesAlloted;
        shares[msg.sender] += sharesAlloted;
    }
}
