// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;
import {Guardrail} from "../../src/Guardrail.sol";

contract GuardrailHarness is Guardrail {
    constructor(uint256 delay) Guardrail(delay) {}

    function getRemovalSchedule(address safe) external view returns (uint256) {
        return removalSchedule[safe];
    }

    function getDelegatedAllowance(address safe, address delegate) public view returns (Allowance memory) {
        return delegatedAllowance[safe][delegate];
    }

    function getDelegatedAllowanceOneTimeBool(address safe, address delegate) external view returns (bool) {
        return getDelegatedAllowance(safe, delegate).oneTimeAllowance;
    }

    function getDelegatedAllowanceTimestamp(address safe, address delegate) external view returns (uint248) {
        return getDelegatedAllowance(safe, delegate).allowedTimestamp;
    }

    function decodeSelectorProperly(bytes calldata data) public pure returns (bool) {
        if (data.length >= 4 || data.length == 0) {
            return true;
        }
        return false;
    }

    function isMultiSendCallData(bytes calldata data) external pure returns (bool) {
        if (decodeSelectorProperly(data)) {
            bytes4 selector = bytes4(data);
            return selector == this.multiSend.selector || selector == this.multiSendNoValue.selector;
        }
        return false;
    }

    function emptyBytes() external pure returns (bytes memory) {
        return bytes("");
    }
}