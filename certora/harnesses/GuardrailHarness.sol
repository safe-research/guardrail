// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;
import {Guardrail} from "../../src/Guardrail.sol";

contract GuardrailHarness is Guardrail {
    constructor(uint256 delay) Guardrail(delay) {}

    function getRemovalSchedule(address safe) external view returns (uint256) {
        return removalSchedule[safe];
    }
}