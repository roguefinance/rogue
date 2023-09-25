// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {Locker} from "src/Locker.sol";

contract Deploy_Eth is Script {

    function run() external {

        address mav = vm.envAddress("MAV_TOKEN_ETH");
        address endpoint = vm.envAddress("LZ_ENDPOINT_ETH");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);

        new Locker(mav, endpoint);

        vm.stopBroadcast();
    }
}