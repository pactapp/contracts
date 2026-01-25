// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {Bank} from "../src/Bank.sol";

contract BankScript is Script {
    Bank public bank;
    address public usdc;

    function setUp() public {
        usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; //mainnet usdc
    }

    function run() public {
        vm.startBroadcast();

        bank = new Bank(usdc);

        vm.stopBroadcast();
    }
}
