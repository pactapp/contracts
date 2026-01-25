// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Owned} from "solmate/auth/Owned.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Bank is Owned {
    // Types
    struct Pact {
        uint256 sharesAmount;
        uint256 unlockTime;
        bool isActive;
    }

    // Global Variables
    address public usdc;

    uint256 public constant penalty = 10_00; // 10%
    uint256 public constant protocolFee = 10_00; // 10% on penalty withdraws, or total 1% of withdraw amount

    // Shares accounting
    uint256 public totalShares;
    mapping(address => uint256) public shares;

    // Pacts management
    mapping(address => Pact[]) public userPacts;

    // Function
    constructor(address _usdc) Owned(owner) {
        owner = msg.sender;
        usdc = _usdc;
    }

    function deposit(uint256 amount, uint256 duration) public {
        require(amount > 0, "Deposit must be more than 0");
        require(duration > 0, "Deposit duration must be more than 0");

        uint256 assetsBefore = getVaultAssetBalance();

        IERC20(usdc).transferFrom(msg.sender, address(this), amount);

        uint256 sharesAlloted;

        if (totalShares == 0) {
            sharesAlloted = amount;
        } else {
            sharesAlloted = amount * totalShares / assetsBefore;
        }

        require(sharesAlloted > 0, "Shares must be more than 0");

        totalShares += sharesAlloted;
        shares[msg.sender] += sharesAlloted;

        userPacts[msg.sender].push(Pact(sharesAlloted, block.timestamp + duration, true));
    }

    // Getter functions
    function getVaultAssetBalance() public view returns (uint256) {
        return IERC20(usdc).balanceOf(address(this));
    }
}
