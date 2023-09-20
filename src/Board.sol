// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Board {
    using SafeERC20 for IERC20;

    uint256 public mavLocked;
    bool public isBoard = true;
    address public mav;

    constructor(address _mav) {
        mav = _mav;
    }

    ////////////////////////////////////////////////////////////////
    //////////////////////////// Lock //////////////////////////////
    ////////////////////////////////////////////////////////////////

    /// @notice called by Locker to trigger lock logic
    function extendLockup(uint256 toLock) external {
        IERC20(mav).safeTransferFrom(msg.sender, address(this), toLock);
        // veMav.extend(INITIAL_ID, maxDuration, toLock, true); // TODO put back for test/prod
        mavLocked += toLock;
    }
}
