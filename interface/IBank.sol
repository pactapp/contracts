// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IBank {
    event Deposited(
        address indexed user,
        uint256 amount,
        uint256 sharesReceived,
        uint256 unlockTime,
        uint256 indexed pactId
    );
    
    event Withdrawn(
        address indexed user,
        uint256 indexed pactId,
        uint256 sharesRedeemed,
        uint256 amountReceived
    );
    
    event ForceWithdrawn(
        address indexed user,
        uint256 indexed pactId,
        uint256 sharesRedeemed,
        uint256 amountReceived,
        uint256 penaltyAmount,
        uint256 protocolCut
    );
    
    event ProtocolFeeWithdrawn(
        address indexed owner,
        uint256 sharesRedeemed,
        uint256 amountReceived
    );
}