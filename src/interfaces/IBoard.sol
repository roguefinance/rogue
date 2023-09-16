// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBoard {
    
    function extendLockup(uint256 _amount) external;
    function isBoard() external pure returns (bool);

}