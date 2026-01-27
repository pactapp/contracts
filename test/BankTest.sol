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

    function testForceWithdraw() public depositUsdc {
        vm.startPrank(user1);

        Bank.Pact[] memory pacts = bank.getUserPacts();
        uint256 pactId = pacts.length - 1;

        uint256 totalSharesBefore = bank.totalShares();
        uint256 userBalanceBefore = usdc.balanceOf(user1);

        bank.forceWithdraw(pactId);

        vm.stopPrank();

        uint256 userSharesAfter = bank.shares(user1);
        uint256 totalSharesAfter = bank.totalShares();
        uint256 userBalanceAfter = usdc.balanceOf(user1);

        assertEq(userSharesAfter, 0);

        uint256 expectedWithdraw = 100e6 * 9000 / 10_000;
        assertEq(userBalanceAfter - userBalanceBefore, expectedWithdraw);

        assertGt(bank.shares(owner), 0);

        assertLt(totalSharesAfter, totalSharesBefore);
        assertGt(totalSharesAfter, 0);
    }

    function testForceWithdrawPenaltyDistribution() public depositUsdc {
        vm.startPrank(user1);

        Bank.Pact[] memory pacts = bank.getUserPacts();
        uint256 pactId = pacts.length - 1;

        uint256 poolAssetsBefore = bank.getVaultAssetBalance();

        bank.forceWithdraw(pactId);

        vm.stopPrank();

        uint256 pactValue = 100e6;
        uint256 penaltyAmount = pactValue * 10_00 / 10_000;
        uint256 protocolCut = penaltyAmount * 10_00 / 10_000;
        uint256 withdrawAmount = pactValue - penaltyAmount;

        uint256 expectedProtocolShares = protocolCut * 100e6 / poolAssetsBefore;

        assertEq(bank.shares(owner), expectedProtocolShares);
        assertEq(usdc.balanceOf(user1), 900e6 + withdrawAmount);
    }

    function testCannotForceWithdrawAfterUnlockTime() public depositUsdc {
        vm.startPrank(user1);

        Bank.Pact[] memory pacts = bank.getUserPacts();
        uint256 pactId = pacts.length - 1;
        Bank.Pact memory pact = pacts[pactId];

        vm.warp(block.timestamp + pact.unlockTime + 1);

        vm.expectRevert("Use normal withdraw");
        bank.forceWithdraw(pactId);

        vm.stopPrank();
    }

    function testCannotForceWithdrawInactivePact() public depositUsdc {
        vm.startPrank(user1);

        Bank.Pact[] memory pacts = bank.getUserPacts();
        uint256 pactId = pacts.length - 1;
        Bank.Pact memory pact = pacts[pactId];

        vm.warp(block.timestamp + pact.unlockTime);
        bank.withdraw(pactId);

        vm.expectRevert("Pact is not active");
        bank.forceWithdraw(pactId);

        vm.stopPrank();
    }

    function testCannotForceWithdrawNonexistentPact() public depositUsdc {
        vm.startPrank(user1);

        vm.expectRevert("Pact does not exist");
        bank.forceWithdraw(999);

        vm.stopPrank();
    }

    function testForceWithdrawMultipleUsers() public depositUsdc {
        address user2 = makeAddr("user2");
        usdc.mint(user2, 1_000e6);

        uint256 lockDuration = 30 * 24 * 60 * 60;

        vm.startPrank(user2);
        usdc.approve(address(bank), 200e6);
        bank.deposit(200e6, lockDuration);
        vm.stopPrank();

        vm.startPrank(user1);
        bank.forceWithdraw(0);
        vm.stopPrank();

        uint256 user2Shares = bank.shares(user2);
        assertGt(user2Shares, 0);

        assertGt(bank.shares(owner), 0);
    }

    function testForceWithdrawZeroPenaltyEdgeCase() public {
        uint256 lockDuration = 30 * 24 * 60 * 60;
        uint256 tinyDeposit = 100;

        usdc.mint(user1, tinyDeposit);

        vm.startPrank(user1);
        usdc.approve(address(bank), tinyDeposit);
        bank.deposit(tinyDeposit, lockDuration);

        bank.forceWithdraw(0);
        vm.stopPrank();

        assertEq(bank.shares(user1), 0);
    }
}
