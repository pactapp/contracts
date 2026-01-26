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
        assertEq(userShares, depositAmount);
    }
}
