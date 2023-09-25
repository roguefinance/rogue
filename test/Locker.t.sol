// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {MockERC20} from "@solmate/test/utils/mocks/MockERC20.sol";
import {Locker} from "src/Locker.sol";
import {Board} from "src/Board.sol";

contract LockerTest is Test {
    Locker locker;
    MockERC20 mav;
    address layerZeroEndpoint = address(1);
    Board board;
    address alice = address(67676);
    address bob = address(9890);

    function setUp() public {
        mav = new MockERC20("MAV", "MAV", 18);
        locker = new Locker(address(mav), layerZeroEndpoint);
        board = new Board(address(mav));
        mav.mint(alice, 1e20 * 1e18);
    }

    ////////////////////////////////////////////////////////////////
    /////////////////////////// User Facing ////////////////////////
    ////////////////////////////////////////////////////////////////

    /// DEPOSIT

    // User should be able to deposit and get rMAV minted
    function test_deposit(uint256 _deposited) public {
        address caller = alice;
        address recipient = bob;

        _deposited = bound(_deposited, 1, mav.balanceOf(caller));

        // deposit
        vm.startPrank(caller);
        mav.approve(address(locker), _deposited);
        locker.deposit(_deposited, recipient);
        vm.stopPrank();

        assertEq(mav.balanceOf(address(locker)), _deposited);
        assertEq(locker.balanceOf(recipient), _deposited);
        assertEq(locker.totalSupply(), _deposited);
    }

    // User shouldn't be able to deposit a null amount
    function test_deposit_zeroAmount() public {
        address caller = alice;
        address recipient = bob;

        // deposit
        vm.startPrank(caller);
        mav.approve(address(locker), 0);
        vm.expectRevert(Locker.ZeroAmount.selector);
        locker.deposit(0, recipient);
        vm.stopPrank();
    }

    /// WITHDRAW

    // User should be able to withdraw and get rMAV burned
    function test_withdraw(uint256 _deposited) public {
        address caller = alice;
        address recipient = bob;

        _deposited = bound(_deposited, 1, mav.balanceOf(caller));

        // deposit
        vm.startPrank(caller);
        mav.approve(address(locker), _deposited);
        locker.deposit(_deposited, recipient);
        vm.stopPrank();

        uint256 lockerBalanceBefore = locker.balanceOf(recipient);
        uint256 mavBalanceBefore = mav.balanceOf(recipient);
        uint256 totalSupplyBefore = locker.totalSupply();

        // withdraw
        vm.startPrank(recipient);
        locker.withdraw(_deposited);
        vm.stopPrank();

        uint256 deltaLocker = lockerBalanceBefore - locker.balanceOf(recipient);
        uint256 deltaMav = mav.balanceOf(recipient) - mavBalanceBefore;
        uint256 deltaSupply = totalSupplyBefore - locker.totalSupply();

        assertEq(deltaLocker, _deposited);
        assertEq(deltaMav, _deposited);
        assertEq(deltaSupply, _deposited);
    }

    // User shouldn't be able to withdraw a null amount
    function test_withdraw_zeroAmount() public {
        address caller = alice;
        address recipient = bob;

        // deposit
        vm.startPrank(caller);
        mav.approve(address(locker), 100);
        locker.deposit(100, recipient);
        vm.stopPrank();

        // withdraw
        vm.startPrank(recipient);
        vm.expectRevert(Locker.ZeroAmount.selector);
        locker.withdraw(0);
        vm.stopPrank();
    }

    // User shouldn't be able to withdraw when withdrawals are disabled
    function test_withdraw_disabled() public {
        address caller = alice;
        address recipient = bob;

        // deposit
        vm.startPrank(caller);
        mav.approve(address(locker), 100);
        locker.deposit(100, recipient);
        vm.stopPrank();

        vm.startPrank(locker.owner());
        locker.setBoard(address(board), 0.01e18);
        vm.warp(locker.boardSetAt() + 3 days);
        locker.disable();
        vm.stopPrank();

        // withdraw
        vm.startPrank(recipient);
        vm.expectRevert(Locker.Disabled.selector);
        locker.withdraw(100);
        vm.stopPrank();
    }

    /// LOCK

    // Bots should be able to lock MAV on veMAV in exchange for an incentive
    function test_lock(uint256 _deposited, uint256 _incentive) public {
        address caller = alice;
        address recipient = bob;
        address incentiveCaller = address(674674);

        _deposited = bound(_deposited, 1, mav.balanceOf(caller));
        _incentive = bound(_incentive, 1, 0.01e18);

        // set board
        vm.startPrank(locker.owner());
        locker.setBoard(address(board), _incentive);
        vm.warp(locker.boardSetAt() + 3 days);
        locker.disable();
        vm.stopPrank();

        // deposit
        vm.startPrank(caller);
        mav.approve(address(locker), _deposited);
        locker.deposit(_deposited, recipient);
        vm.stopPrank();

        // lock
        vm.startPrank(incentiveCaller);
        locker.lock();
        vm.stopPrank();

        assertEq(mav.balanceOf(address(locker)), 0);
        assertEq(board.mavLocked(), _deposited);
        assertEq(locker.balanceOf(incentiveCaller), _deposited * locker.callIncentive() / locker.ONE());
    }

    // Bots shouldn't be able to lock MAV on veMAV when board is not set
    function test_lock_notDisabled() public {
        address caller = alice;
        address recipient = bob;
        address incentiveCaller = address(674674);

        uint256 deposited = 1e18;

        // deposit
        vm.startPrank(caller);
        mav.approve(address(locker), deposited);
        locker.deposit(deposited, recipient);
        vm.stopPrank();

        // lock
        vm.startPrank(incentiveCaller);
        vm.expectRevert(Locker.NotDisabled.selector);
        locker.lock();
        vm.stopPrank();
    }

    // Bots shouldn't be able to lock MAV on veMAV when no MAV is deposited
    function test_lock_noDeposit() public {
        address incentiveCaller = address(674674);

        vm.startPrank(locker.owner());
        locker.setBoard(address(board), 0.01e18);
        vm.warp(locker.boardSetAt() + 3 days);
        locker.disable();
        vm.stopPrank();

        vm.startPrank(incentiveCaller);

        vm.expectRevert(Locker.NoDeposit.selector);
        locker.lock();

        vm.stopPrank();
    }

    ////////////////////////////////////////////////////////////////
    ////////////////////////////// Owner ///////////////////////////
    ////////////////////////////////////////////////////////////////

    // Owner should be able to set the board
    function test_setBoard() public {
        vm.startPrank(locker.owner());
        locker.setBoard(address(board), 0.01e18);
        vm.stopPrank();
        assertEq(address(locker.board()), address(board));
        assertEq(locker.boardSetAt(), block.timestamp);
    }

    // Owner shouldn't be able to set the board if it's already set
    function test_setBoard_alreadySet() public {
        vm.startPrank(locker.owner());
        locker.setBoard(address(board), 0.01e18);

        vm.expectRevert(Locker.BoardAlreadySet.selector);
        locker.setBoard(address(board), 0.01e18);

        vm.stopPrank();
    }

    // Owner shouldn't be able to set the board if the incentive is invalid
    function test_setBoard_invalidValue() public {
        uint256 invalidIncentive = 0.01e18 + 1;
        vm.startPrank(locker.owner());
        bytes memory revertData = abi.encodeWithSelector(Locker.InvalidIncentiveValue.selector, invalidIncentive);

        vm.expectRevert(revertData);
        locker.setBoard(address(board), invalidIncentive);

        vm.stopPrank();
    }

    // Owner should be able to update the incentive
    function test_updateIncentive(uint256 _incentive) public {
        _incentive = bound(_incentive, 1, 0.01e18);

        vm.startPrank(locker.owner());
        locker.updateIncentive(_incentive);
        vm.stopPrank();

        assertEq(locker.callIncentive(), _incentive);
    }

    // Owner shouldn't be able to update the incentive if it's invalid
    function test_updateIncentive_wrongValue() public {
        uint256 invalidIncentive = 0.01e18 + 1;
        vm.startPrank(locker.owner());
        bytes memory revertData = abi.encodeWithSelector(Locker.InvalidIncentiveValue.selector, invalidIncentive);
        vm.expectRevert(revertData);

        locker.updateIncentive(invalidIncentive);

        vm.stopPrank();
    }

    // Owner should be able to disable withdrawals if timelock has passed
    function test_disable() public {
        uint256 callIncentive = 0.01e18;
        vm.startPrank(locker.owner());
        locker.setBoard(address(board), callIncentive);

        vm.warp(locker.boardSetAt() + 3 days);

        locker.disable();
        vm.stopPrank();
        assertTrue(locker.disabled());
    }

    // Owner shouldn't be able to disable withdrawals if timelock hasn't passed
    function test_disable_timelock_not_passed() public {
        uint256 callIncentive = 0.01e18;
        vm.startPrank(locker.owner());
        locker.setBoard(address(board), callIncentive);

        vm.warp(locker.boardSetAt() + 3 days - 1);

        vm.expectRevert(Locker.TimelockPeriodNotPassed.selector);

        locker.disable();
        vm.stopPrank();
    }

    // Owner shouldn't be able to disable withdrawals if they're already disabled
    function test_disable_already_disabled() public {
        uint256 callIncentive = 0.01e18;
        vm.startPrank(locker.owner());
        locker.setBoard(address(board), callIncentive);

        vm.warp(locker.boardSetAt() + 3 days);

        locker.disable();

        vm.expectRevert(Locker.InvalidDisabling.selector);

        locker.disable();
        vm.stopPrank();
    }
    
    // Owner shouldn't be able to disable withdrawals if the board is not set
    function test_disable_board_not_set() public {
        vm.startPrank(locker.owner());
        vm.expectRevert(Locker.InvalidDisabling.selector);
        locker.disable();
        vm.stopPrank();
    }
}
