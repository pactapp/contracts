// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Bank} from "../src/Bank.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";

contract CounterTest is Test {
    Bank public bank;
    MockUSDC public usdc;

    address public owner;
    address public user1;

    modifier depositUsdc() {
        uint256 lockDuration = 30 * 24 * 60 * 60;
        uint256 depositAmount = 100e6;

        vm.startPrank(user1);
        usdc.approve(address(bank), depositAmount);
        bank.deposit(100e6, lockDuration);
        vm.stopPrank();

        _;
    }

    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");

        vm.startPrank(owner);

        usdc = new MockUSDC();
        bank = new Bank(address(usdc));

        vm.stopPrank();

        usdc.mint(user1, 1_000e6);
    }

    function testDeposit() public {
        uint256 lockDuration = 30 * 24 * 60 * 60;
        uint256 depositAmount = 100e6;

        vm.startPrank(user1);
        usdc.approve(address(bank), depositAmount);
        bank.deposit(100e6, lockDuration);
        vm.stopPrank();

        uint256 userShares = bank.shares(user1);
        uint256 totalShares = bank.totalShares();

        assertEq(userShares, depositAmount);
        assertEq(totalShares, depositAmount);
    }

    function testWithdraw() public depositUsdc {
        vm.startPrank(user1);

        Bank.Pact[] memory pacts = bank.getUserPacts();
        uint256 pactId = pacts.length - 1;

        Bank.Pact memory pact = pacts[pactId];

        vm.warp(block.timestamp + pact.unlockTime);

        bank.withdraw(pactId);

        vm.stopPrank();

        uint256 userShares = bank.shares(user1);
        uint256 totalShares = bank.totalShares();

        assertEq(userShares, 0);
        assertEq(totalShares, 0);
    }

    function testCannotWithdrawBeforeDeadline() public depositUsdc {
        vm.startPrank(user1);

        Bank.Pact[] memory pacts = bank.getUserPacts();
        uint256 pactId = pacts.length - 1;

        vm.expectRevert("Pact is not unlocked yet");
        bank.withdraw(pactId);

        vm.stopPrank();
    }
}
