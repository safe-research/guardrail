// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity =0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {Guardrail} from "../src/Guardrail.sol";

contract GuardrailTest is Test {
    Guardrail public guardrail;

    function setUp() public {
        guardrail = new Guardrail();
    }

    function testGuardrailDeployment() public view {
        // Dummy test
        assert(address(guardrail) != address(0));
    }
}
