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
    function test_deposit(uint _deposited) public {
        
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
    function testFail_deposit_zeroAmount() public {
        address caller = alice;
        address recipient = bob;

        // deposit
        vm.startPrank(caller);
        mav.approve(address(locker), 0);
        locker.deposit(0, recipient);
        vm.stopPrank();
    }

    /// WITHDRAW

    // User should be able to withdraw and get rMAV burned
    function test_withdraw(uint _deposited) public {

        address caller = alice;
        address recipient = bob;

        _deposited = bound(_deposited, 1, mav.balanceOf(caller));

        // deposit
        vm.startPrank(caller);
        mav.approve(address(locker), _deposited);
        locker.deposit(_deposited, recipient);
        vm.stopPrank();

        uint lockerBalanceBefore = locker.balanceOf(recipient);
        uint mavBalanceBefore = mav.balanceOf(recipient);
        uint totalSupplyBefore = locker.totalSupply();

        // withdraw
        vm.startPrank(recipient);
        locker.withdraw(_deposited);
        vm.stopPrank();

        uint deltaLocker = lockerBalanceBefore - locker.balanceOf(recipient);
        uint deltaMav = mav.balanceOf(recipient) - mavBalanceBefore;
        uint deltaSupply = totalSupplyBefore - locker.totalSupply();

        assertEq(deltaLocker, _deposited);
        assertEq(deltaMav, _deposited);
        assertEq(deltaSupply, _deposited);
    }

    // User shouldn't be able to withdraw a null amount
    function testFail_withdraw_zeroAmount() public {
        address caller = alice;
        address recipient = bob;

        // deposit
        vm.startPrank(caller);
        mav.approve(address(locker), 100);
        locker.deposit(100, recipient);
        vm.stopPrank();

        // withdraw
        vm.startPrank(recipient);
        locker.withdraw(0);
        vm.stopPrank();
    }

    // User shouldn't be able to withdraw when withdrawals are disabled
    function testFail_withdraw_disabled() public {
        address caller = alice;
        address recipient = bob;

        // deposit
        vm.startPrank(caller);
        mav.approve(address(locker), 100);
        locker.deposit(100, recipient);
        vm.stopPrank();

        vm.startPrank(locker.owner());
        locker.disable();
        vm.stopPrank();

        // withdraw
        vm.startPrank(recipient);
        locker.withdraw(100);
        vm.stopPrank();
    }

    /// LOCK

    // Bots should be able to lock MAV on veMAV in exchange for an incentive
    function test_lock(uint _deposited, uint _incentive) public {

        address caller = alice;
        address recipient = bob;
        address incentiveCaller = address(674674);

        _deposited = bound(_deposited, 1, mav.balanceOf(caller));
        _incentive = bound(_incentive, 1, 0.01e18);

        // set board
        vm.startPrank(locker.owner());
        locker.setBoard(address(board), _incentive);
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

    function testFail_lock_withdrawals_enabled() public {
        address caller = alice;
        address recipient = bob;
        address incentiveCaller = address(674674);
        
        uint deposited = 1e18;

        // deposit
        vm.startPrank(caller);
        mav.approve(address(locker), deposited);
        locker.deposit(deposited, recipient);
        vm.stopPrank();

        vm.startPrank(locker.owner());
        locker.setBoard(address(board), 0.01e18);
        vm.stopPrank();

        // lock
        vm.startPrank(incentiveCaller);
        locker.lock();
        vm.stopPrank();
    }

    // Bots shouldn't be able to lock MAV on veMAV when board is not set
    function testFail_lock_BoardNotSet() public {
        address caller = alice;
        address recipient = bob;
        address incentiveCaller = address(674674);
        
        uint deposited = 1e18;

        // deposit
        vm.startPrank(caller);
        mav.approve(address(locker), deposited);
        locker.deposit(deposited, recipient);
        vm.stopPrank();

        // lock
        vm.startPrank(incentiveCaller);
        locker.lock();
        vm.stopPrank();
    }

    // Bots shouldn't be able to lock MAV on veMAV when no MAV is deposited
    function testFail_lock_noDeposit() public {

        address incentiveCaller = address(674674);

        vm.startPrank(locker.owner());
        locker.setBoard(address(board), 0.01e18);
        vm.stopPrank();

        // lock
        vm.startPrank(incentiveCaller);
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
    }

    // Owner shouldn't be able to set the board if it's already set
    function testFail_setBoard_alreadySet() public {
        vm.startPrank(locker.owner());
        locker.setBoard(address(board), 0.01e18);
        locker.setBoard(address(board), 0.01e18);
        vm.stopPrank();
    }

    // Owner shouldn't be able to set the board if the incentive is invalid
    function testFail_setBoard_invalidValue() public {
        vm.startPrank(locker.owner());
        locker.setBoard(address(board), 0);
        vm.stopPrank();
    }

    // Owner should be able to update the incentive
    function test_updateIncentive(uint _incentive) public {
        _incentive = bound(_incentive, 1, 0.01e18);

        vm.startPrank(locker.owner());
        locker.updateIncentive(_incentive);
        vm.stopPrank();

        assertEq(locker.callIncentive(), _incentive);
    }

    // Owner shouldn't be able to update the incentive if it's invalid
    function testFail_updateIncentive_wrongValue() public {
        uint invalidIncentive = 0.01e18 + 1;
        vm.startPrank(locker.owner());
        locker.updateIncentive(invalidIncentive);
        vm.stopPrank();
    }

    // Owner should be able to disable withdrawals
    function test_disable() public {
        vm.startPrank(locker.owner());
        locker.disable();
        vm.stopPrank();
        assertTrue(locker.disabled());
    }
}