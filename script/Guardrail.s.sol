// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {Guardrail} from "../src/Guardrail.sol";

contract GuardrailScript is Script {
    Guardrail public guardrail;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        guardrail = new Guardrail();

        vm.stopBroadcast();
    }
}
