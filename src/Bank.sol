// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Owned} from "solmate/auth/Owned.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IBank} from "../interface/IBank.sol";

contract Bank is Owned, IBank {

    // Types
    struct Pact {
        uint256 sharesAmount;
        uint256 unlockTime;
        bool isActive;
    }

    // Global Variables
    address public usdc;

    uint256 public constant PENALTY = 10_00; // 10%
    uint256 public constant PROTOCOL_FEE = 10_00; // 10% on penalty withdraws, or total 1% of withdraw amount

    // Shares accounting
    uint256 public totalShares;
    mapping(address => uint256) public shares;

    // Pacts management
    mapping(address => Pact[]) public userPacts;

    // Function
    constructor(address _usdc) Owned(msg.sender) {
        usdc = _usdc;
    }

    function deposit(uint256 amount, uint256 duration) public {
        require(amount > 0, "Deposit must be more than 0");
        require(duration > 0, "Deposit duration must be more than 0");

        uint256 assetsBefore = getVaultAssetBalance();

        bool success = IERC20(usdc).transferFrom(msg.sender, address(this), amount);

        require(success, "Transfer failed");

        uint256 sharesAlloted;

        if (totalShares == 0) {
            sharesAlloted = amount;
        } else {
            sharesAlloted = amount * totalShares / assetsBefore;
        }

        require(sharesAlloted > 0, "Shares must be more than 0");

        totalShares += sharesAlloted;
        shares[msg.sender] += sharesAlloted;

        uint256 pactId = userPacts[msg.sender].length;
        uint256 unlockTime = block.timestamp + duration;

        userPacts[msg.sender].push(
            Pact({sharesAmount: sharesAlloted, unlockTime: block.timestamp + duration, isActive: true})
        );

        emit Deposited(msg.sender, amount, sharesAlloted, unlockTime, pactId);
    }

    function withdraw(uint256 pactId) public returns (bool) {
        Pact[] storage pacts = userPacts[msg.sender];

        require(pactId < pacts.length, "Pact does not exist");

        Pact storage pact = pacts[pactId];

        require(pact.isActive, "Pact is not active");
        require(pact.unlockTime <= block.timestamp, "Pact is not unlocked yet");

        uint256 poolAssets = getVaultAssetBalance();
        uint256 withdrawAmount = pact.sharesAmount * poolAssets / totalShares;
        uint256 sharesRedeemed = pact.sharesAmount;

        pact.isActive = false;
        shares[msg.sender] -= pact.sharesAmount;
        totalShares -= pact.sharesAmount;
        pact.sharesAmount = 0;

        require(IERC20(usdc).transfer(msg.sender, withdrawAmount), "Transfer failed");

        emit Withdrawn(msg.sender, pactId, sharesRedeemed, withdrawAmount);

        return true;
    }

    function forceWithdraw(uint256 pactId) public returns (bool) {
        Pact[] storage pacts = userPacts[msg.sender];

        require(pactId < pacts.length, "Pact does not exist");

        Pact storage pact = pacts[pactId];

        require(pact.isActive, "Pact is not active");
        require(pact.unlockTime > block.timestamp, "Use normal withdraw");

        uint256 poolAssets = getVaultAssetBalance();
        uint256 pactShares = pact.sharesAmount;
        uint256 totalSharesBefore = totalShares;
        uint256 pactValue = pactShares * poolAssets / totalSharesBefore;
        uint256 penaltyAmount = pactValue * PENALTY / 10_000;
        uint256 protocolCut = penaltyAmount * PROTOCOL_FEE / 10_000;
        uint256 withdrawAmount = pactValue - penaltyAmount;

        pact.isActive = false;
        pact.sharesAmount = 0;
        shares[msg.sender] -= pactShares;
        totalShares -= pactShares;

        require(IERC20(usdc).transfer(msg.sender, withdrawAmount), "User transfer failed");

        if (protocolCut > 0) {
            uint256 remainingAssets = poolAssets - withdrawAmount;
            uint256 protocolShares = totalShares == 0 ? protocolCut : protocolCut * totalShares / remainingAssets;

            shares[owner] += protocolShares;
            totalShares += protocolShares;
        }

        emit ForceWithdrawn(msg.sender, pactId, pactShares, withdrawAmount, penaltyAmount, protocolCut);

        return true;
    }

    function withdrawProtocolFee() public onlyOwner {
        uint256 protocolShares = shares[owner];

        require(protocolShares > 0, "No fee collected");
        require(totalShares > 0, "No shares in system");

        uint256 poolAssets = getVaultAssetBalance();
        uint256 withdrawAmount = protocolShares * poolAssets / totalShares;

        require(withdrawAmount > 0, "Withdraw amount is 0");

        shares[owner] = 0;
        totalShares -= protocolShares;

        require(IERC20(usdc).transfer(owner, withdrawAmount), "User transfer failed");

        emit ProtocolFeeWithdrawn(owner, protocolShares, withdrawAmount);
    }

    // Getter functions
    function getVaultAssetBalance() public view returns (uint256) {
        return IERC20(usdc).balanceOf(address(this));
    }

    function getUserPacts() public view returns (Pact[] memory) {
        return userPacts[msg.sender];
    }
}
