// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {OFT} from "@layerzerolabs/solidity-examples/contracts/token/oft/OFT.sol";

import {IBoard} from "./interfaces/IBoard.sol";

contract Locker is OFT {
    using SafeERC20 for IERC20;

    error ZeroAmount();
    error NoDeposit();
    error BoardAlreadySet();
    error Disabled();
    error NotDisabled();
    error InvalidIncentiveValue(uint256 incentive);
    error InvalidBoard();
    error TimelockPeriodNotPassed();
    error AlreadyDisabled();

    event BoardSet(address board, uint256 incentive);
    event IncentiveUpdated(uint256 incentive);
    event WithdrawalsDisabled();

    /// @notice address of MAV token
    IERC20 public immutable mav;

    /// @notice amount of MAV locked on Rogue
    uint256 public totalLocked;

    /// @notice address of the Board contract
    address public board;

    /// @notice current incentive to call lock
    uint256 public callIncentive;

    /// @notice returns true if withdrawals are disabled
    bool public disabled;

    /// @notice timestamp when board was set
    uint256 public boardSetAt;

    /// @notice 100%
    uint256 public constant ONE = 1e18;

    /// @notice 1%
    uint256 public constant maxIncentive = 0.01e18;

    /// @param _mav address of MAV contract
    /// @param _lzEndPoint address of LayerZero endpoint
    constructor(address _mav, address _lzEndPoint) OFT("Rogue MAV", "rMAV", _lzEndPoint) {
        mav = IERC20(_mav);
    }

    ////////////////////////////////////////////////////////////////
    ////////////////////////// User Facing /////////////////////////
    ////////////////////////////////////////////////////////////////

    /// @notice deposit MAV, pulls MAV from caller and mint rMAV to `recipient`
    /// @param amount amount of MAV to lock pulled from `msg.sender`
    /// @param recipient address to mint rMAV to
    function deposit(uint256 amount, address recipient) external {
        if (amount == 0) revert ZeroAmount();
        mav.safeTransferFrom(msg.sender, address(this), amount);
        _mint(recipient, amount);
    }

    /// @notice withdraw MAV and burn rMAV
    /// @param amount amount of rMAV to withdraw
    function withdraw(uint256 amount) external {
        if (disabled) revert Disabled();
        if (amount == 0) revert ZeroAmount();
        _burn(msg.sender, amount);
        mav.safeTransfer(msg.sender, amount);
    }

    /// @notice extend locks, caller get rMAV minted as incentive
    function lock() external {
        if (!disabled) revert NotDisabled();
        uint256 balance = mav.balanceOf(address(this));
        if (balance == 0) revert NoDeposit();
        uint256 incentive = balance * callIncentive / ONE;
        _mint(msg.sender, incentive);
        IBoard(board).extendLockup(balance);
    }

    ////////////////////////////////////////////////////////////////
    //////////////////////////// Owner /////////////////////////////
    ////////////////////////////////////////////////////////////////

    /// @notice update the board address, one time call
    /// @param _board address of the new board
    function setBoard(address _board, uint256 _callIncentive) external onlyOwner {
        if (board != address(0)) revert BoardAlreadySet();
        if (!IBoard(_board).isBoard()) revert InvalidBoard();
        if (_callIncentive == 0 || _callIncentive > maxIncentive) revert InvalidIncentiveValue(_callIncentive);
        board = _board;
        callIncentive = _callIncentive;
        boardSetAt = block.timestamp;
        mav.safeApprove(_board, type(uint256).max);
        emit BoardSet(_board, _callIncentive);
    }

    /// @notice updates the incentive rate for calling lock limiting it to 1%
    /// @param _callIncentive new incentive rate
    function updateIncentive(uint256 _callIncentive) external onlyOwner {
        if (_callIncentive == 0 || _callIncentive > maxIncentive) revert InvalidIncentiveValue(_callIncentive);
        callIncentive = _callIncentive;
        emit IncentiveUpdated(_callIncentive);
    }

    /// @notice disable withdrawals
    function disable() external onlyOwner {
        if (disabled) revert AlreadyDisabled();
        if (boardSetAt + 3 days < block.timestamp) revert TimelockPeriodNotPassed();
        disabled = true;
        emit WithdrawalsDisabled();
    }
}