// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {Bank} from "../../src/Bank.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";
import {IBank} from "../../interface/IBank.sol";


contract BankFuzzTest is Test {
    Bank public bank;
    MockUSDC public usdc;

    address public owner;
    address public user1;
    address public user2;

    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        vm.prank(owner);
        usdc = new MockUSDC();
        
        vm.prank(owner);
        bank = new Bank(address(usdc));
    }

    function testFuzz_DepositWithRandomAmounts(uint256 amount, uint256 duration) public {
        amount = bound(amount, 1, 1_000_000e6); 
        duration = bound(duration, 1, 365 days);

        usdc.mint(user1, amount);

        uint256 userSharesBefore = bank.shares(user1);
        uint256 totalSharesBefore = bank.totalShares();
        uint256 vaultBalanceBefore = bank.getVaultAssetBalance();

        vm.startPrank(user1);
        usdc.approve(address(bank), amount);
        bank.deposit(amount, duration);
        vm.stopPrank();

        uint256 userSharesAfter = bank.shares(user1);
        uint256 totalSharesAfter = bank.totalShares();
        uint256 vaultBalanceAfter = bank.getVaultAssetBalance();

        
        assertGt(userSharesAfter, userSharesBefore, "User should have received shares");
        
        assertGt(totalSharesAfter, totalSharesBefore, "Total shares should have increased");
        
        assertEq(vaultBalanceAfter, vaultBalanceBefore + amount, "Vault should have received USDC");
        
        assertEq(userSharesAfter, totalSharesAfter, "User shares should equal total shares");

        vm.startPrank(user1);
        Bank.Pact[] memory pacts = bank.getUserPacts();
        vm.stopPrank();

        assertEq(pacts.length, 1, "Should have created 1 pact");
        assertEq(pacts[0].sharesAmount, userSharesAfter, "Pact shares should match user shares");
        assertTrue(pacts[0].isActive, "Pact should be active");
        assertEq(pacts[0].unlockTime, block.timestamp + duration, "Unlock time should be correct");
    }

    function testFuzz_FirstDepositGivesOneToOneShares(uint256 amount) public {
        amount = bound(amount, 1, 1_000_000e6);

        usdc.mint(user1, amount);

        vm.startPrank(user1);
        usdc.approve(address(bank), amount);
        bank.deposit(amount, 30 days);
        vm.stopPrank();

        assertEq(bank.shares(user1), amount, "First deposit should be 1:1 shares");
        assertEq(bank.totalShares(), amount, "Total shares should equal deposited amount");
    }

    function testFuzz_MultipleDepositsProportionalShares(uint256 amount1, uint256 amount2) public {
        amount1 = bound(amount1, 100e6, 1_000_000e6); 
        amount2 = bound(amount2, 100e6, 1_000_000e6);  

        usdc.mint(user1, amount1);
        vm.startPrank(user1);
        usdc.approve(address(bank), amount1);
        bank.deposit(amount1, 30 days);
        vm.stopPrank();

        uint256 user1Shares = bank.shares(user1);

        usdc.mint(user2, amount2);
        vm.startPrank(user2);
        usdc.approve(address(bank), amount2);
        bank.deposit(amount2, 30 days);
        vm.stopPrank();

        uint256 user2Shares = bank.shares(user2);

        uint256 expectedUser2Shares = amount2 * user1Shares / amount1;

        assertEq(user2Shares, expectedUser2Shares, "User2 shares should be proportional");

        assertEq(bank.totalShares(), user1Shares + user2Shares, "Total shares should equal sum");

        assertEq(bank.getVaultAssetBalance(), amount1 + amount2, "Vault should have total deposits");
    }

    function testFuzz_SmallDepositsDontRoundToZero(uint256 amount) public {
        amount = bound(amount, 1, 1000);

        usdc.mint(user1, amount);

        vm.startPrank(user1);
        usdc.approve(address(bank), amount);
        bank.deposit(amount, 30 days);
        vm.stopPrank();

        assertGt(bank.shares(user1), 0, "Small deposits should give non-zero shares");
    }

    function testFuzz_DepositRevertsWithZeroAmount(uint256 duration) public {
        duration = bound(duration, 1, 365 days);

        vm.startPrank(user1);
        usdc.approve(address(bank), 0);
        
        vm.expectRevert(IBank.ZeroAmount.selector);
        bank.deposit(0, duration);
        
        vm.stopPrank();
    }

    function testFuzz_DepositRevertsWithZeroDuration(uint256 amount) public {
        amount = bound(amount, 1, 1_000_000e6);

        usdc.mint(user1, amount);

        vm.startPrank(user1);
        usdc.approve(address(bank), amount);
        
        vm.expectRevert(IBank.ZeroDuration.selector);
        bank.deposit(amount, 0);
        
        vm.stopPrank();
    }


    function testFuzz_UnlockTimeIsCorrect(uint256 duration) public {
        duration = bound(duration, 1 days, 365 days);

        uint256 depositAmount = 100e6;
        usdc.mint(user1, depositAmount);

        uint256 depositTime = block.timestamp;

        vm.startPrank(user1);
        usdc.approve(address(bank), depositAmount);
        bank.deposit(depositAmount, duration);
         Bank.Pact[] memory pacts = bank.getUserPacts();
        vm.stopPrank();

        
        assertEq(pacts[0].unlockTime, depositTime + duration, "Unlock time should be correct");
    }

    function testFuzz_MultiplePactsPerUser(
        uint256 amount1,
        uint256 amount2,
        uint256 duration1,
        uint256 duration2
    ) public {
        amount1 = bound(amount1, 1e6, 500_000e6);
        amount2 = bound(amount2, 1e6, 500_000e6);
        duration1 = bound(duration1, 1 days, 365 days);
        duration2 = bound(duration2, 1 days, 365 days);

        usdc.mint(user1, amount1 + amount2);

        vm.startPrank(user1);
        usdc.approve(address(bank), amount1);
        bank.deposit(amount1, duration1);

        uint256 sharesAfterFirst = bank.shares(user1);

        usdc.approve(address(bank), amount2);
        bank.deposit(amount2, duration2);
        vm.stopPrank();

        uint256 sharesAfterSecond = bank.shares(user1);

        vm.startPrank(user1);
        Bank.Pact[] memory pacts = bank.getUserPacts();
        vm.stopPrank();

        assertEq(pacts.length, 2, "Should have 2 pacts");

        assertTrue(pacts[0].isActive, "First pact should be active");
        assertTrue(pacts[1].isActive, "Second pact should be active");

        assertGt(sharesAfterSecond, sharesAfterFirst, "Shares should increase after second deposit");

        assertEq(bank.getVaultAssetBalance(), amount1 + amount2, "Vault should have both deposits");
    }
}