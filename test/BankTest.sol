// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

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

    function testWithdrawProtocolFee() public depositUsdc {
        vm.startPrank(user1);
        bank.forceWithdraw(0);
        vm.stopPrank();

        uint256 ownerSharesBefore = bank.shares(owner);
        uint256 totalSharesBefore = bank.totalShares();
        uint256 ownerBalanceBefore = usdc.balanceOf(owner);
        uint256 poolAssetsBefore = bank.getVaultAssetBalance();

        require(ownerSharesBefore > 0, "Owner should have shares from protocol fee");

        vm.prank(owner);
        bank.withdrawProtocolFee();

        uint256 ownerSharesAfter = bank.shares(owner);
        uint256 totalSharesAfter = bank.totalShares();
        uint256 ownerBalanceAfter = usdc.balanceOf(owner);

        assertEq(ownerSharesAfter, 0);

        assertEq(totalSharesAfter, totalSharesBefore - ownerSharesBefore);

        uint256 expectedWithdraw = ownerSharesBefore * poolAssetsBefore / totalSharesBefore;
        assertEq(ownerBalanceAfter - ownerBalanceBefore, expectedWithdraw);

        assertGt(ownerBalanceAfter, ownerBalanceBefore);
    }

    function testCannotWithdrawProtocolFeeWithNoFees() public {
        vm.prank(owner);
        vm.expectRevert("No fee collected");
        bank.withdrawProtocolFee();
    }

    function testCannotWithdrawProtocolFeeAsNonOwner() public depositUsdc {
        vm.prank(user1);
        bank.forceWithdraw(0);

        vm.prank(user1);
        vm.expectRevert("UNAUTHORIZED");
        bank.withdrawProtocolFee();
    }

    function testWithdrawProtocolFeeMultipleTimes() public depositUsdc {
        vm.prank(user1);
        bank.forceWithdraw(0);

        vm.prank(owner);
        bank.withdrawProtocolFee();

        uint256 ownerShares = bank.shares(owner);
        assertEq(ownerShares, 0);

        uint256 lockDuration = 30 * 24 * 60 * 60;
        vm.startPrank(user1);
        usdc.approve(address(bank), 100e6);
        bank.deposit(100e6, lockDuration);
        bank.forceWithdraw(1);
        vm.stopPrank();

        ownerShares = bank.shares(owner);
        assertGt(ownerShares, 0);

        vm.prank(owner);
        bank.withdrawProtocolFee();

        ownerShares = bank.shares(owner);
        assertEq(ownerShares, 0);
    }

    function testWithdrawProtocolFeeWithMultipleUsersForceWithdrawing() public depositUsdc {
        address user2 = makeAddr("user2");
        usdc.mint(user2, 1_000e6);

        uint256 lockDuration = 30 * 24 * 60 * 60;

        vm.startPrank(user2);
        usdc.approve(address(bank), 200e6);
        bank.deposit(200e6, lockDuration);
        vm.stopPrank();

        vm.prank(user1);
        bank.forceWithdraw(0);

        vm.prank(user2);
        bank.forceWithdraw(0);

        uint256 ownerShares = bank.shares(owner);
        assertGt(ownerShares, 0);

        uint256 poolAssets = bank.getVaultAssetBalance();
        uint256 totalShares = bank.totalShares();
        uint256 expectedWithdraw = ownerShares * poolAssets / totalShares;

        vm.prank(owner);
        bank.withdrawProtocolFee();

        uint256 ownerBalance = usdc.balanceOf(owner);
        assertEq(ownerBalance, expectedWithdraw);
    }

    function testWithdrawProtocolFeeAccountingCorrectness() public depositUsdc {
        vm.prank(user1);
        bank.forceWithdraw(0);

        uint256 totalSharesBefore = bank.totalShares();
        uint256 poolAssetsBefore = bank.getVaultAssetBalance();
        uint256 ownerSharesBefore = bank.shares(owner);

        uint256 expectedWithdrawAmount = ownerSharesBefore * poolAssetsBefore / totalSharesBefore;
        uint256 expectedRemainingAssets = poolAssetsBefore - expectedWithdrawAmount;
        uint256 expectedRemainingShares = totalSharesBefore - ownerSharesBefore;

        vm.prank(owner);
        bank.withdrawProtocolFee();

        assertEq(bank.totalShares(), expectedRemainingShares);
        assertEq(bank.getVaultAssetBalance(), expectedRemainingAssets);
        assertEq(bank.shares(owner), 0);
    }

    function testWithdrawProtocolFeeDoesNotAffectOtherUsers() public depositUsdc {
        address user2 = makeAddr("user2");
        usdc.mint(user2, 1_000e6);

        uint256 lockDuration = 30 * 24 * 60 * 60;

        vm.startPrank(user2);
        usdc.approve(address(bank), 200e6);
        bank.deposit(200e6, lockDuration);
        vm.stopPrank();

        uint256 user2SharesBefore = bank.shares(user2);

        vm.prank(user1);
        bank.forceWithdraw(0);

        vm.prank(owner);
        bank.withdrawProtocolFee();

        uint256 user2SharesAfter = bank.shares(user2);
        assertEq(user2SharesAfter, user2SharesBefore);

        vm.warp(block.timestamp + lockDuration);

        uint256 user2BalanceBefore = usdc.balanceOf(user2);

        vm.prank(user2);
        bank.withdraw(0);

        uint256 user2BalanceAfter = usdc.balanceOf(user2);
        uint256 user2Received = user2BalanceAfter - user2BalanceBefore;

        assertGt(user2Received, 200e6);

        assertApproxEqAbs(user2Received, 209e6, 1e6);
    }

    function testWithdrawProtocolFeeEmptyPoolEdgeCase() public depositUsdc {
        vm.prank(user1);
        bank.forceWithdraw(0);

        vm.prank(owner);
        bank.withdrawProtocolFee();

        vm.prank(owner);
        vm.expectRevert("No fee collected");
        bank.withdrawProtocolFee();
    }

    function testWithdrawProtocolFeeRoundingBehavior() public {
        uint256 lockDuration = 30 * 24 * 60 * 60;
        uint256 tinyDeposit = 1000;

        usdc.mint(user1, tinyDeposit);

        vm.startPrank(user1);
        usdc.approve(address(bank), tinyDeposit);
        bank.deposit(tinyDeposit, lockDuration);
        bank.forceWithdraw(0);
        vm.stopPrank();

        uint256 ownerShares = bank.shares(owner);

        if (ownerShares > 0) {
            vm.prank(owner);
            bank.withdrawProtocolFee();

            assertEq(bank.shares(owner), 0);
        }
    }

    function testWithdrawProtocolFeeGasUsage() public depositUsdc {
        vm.prank(user1);
        bank.forceWithdraw(0);

        vm.prank(owner);
        uint256 gasBefore = gasleft();
        bank.withdrawProtocolFee();
        uint256 gasUsed = gasBefore - gasleft();

        assertTrue(gasUsed > 0);
    }
}
