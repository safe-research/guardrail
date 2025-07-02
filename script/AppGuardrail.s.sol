// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {AppGuardrail} from "../src/test/AppGuardrail.sol";

contract AppGuardrailScript is Script {
    AppGuardrail public appGuardrail;

    function setUp() public {}

    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        uint256 delay = 180;
        appGuardrail = new AppGuardrail(delay);

        vm.stopBroadcast();
    }
}
