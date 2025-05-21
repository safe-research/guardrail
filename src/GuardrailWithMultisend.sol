// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity =0.8.28;

import {Guardrail, Enum} from "./Guardrail.sol";
import {MultiSendCallOnly} from "safe-smart-account/contracts/libraries/MultiSendCallOnly.sol";

contract GuardrailWithMultisend is Guardrail, MultiSendCallOnly {
    /**
     * @notice The constructor for the Guardrail contract
     * @param delay The delay for the guard removal and delegate allowance
     */
    constructor(uint256 delay) Guardrail(delay) {}

    /**
     * @notice Function to check if the delegate is allowed if the operation is delegate call
     * @param safe The address of the safe
     * @param to The address of the delegate
     * @param operation The operation to check
     * @dev This will revert if the operation is delegate call, but the {to} is not a allowed delegate. This will also
     *      remove the delegate allowance if the one time allowance is set
     */
    function _checkOperationAndAllowance(address safe, address to, Enum.Operation operation) internal override {
        if (to == address(this)) {
            // Question: Should we also check if the selector is `multiSend(...)`?
            return;
        }

        if (operation == Enum.Operation.DelegateCall) {
            Allowance memory allowance = delegatedAllowance[safe][to];
            require(
                allowance.allowedTimestamp > 0 && allowance.allowedTimestamp < block.timestamp,
                DelegateCallNotAllowed(to)
            );

            if (allowance.oneTimeAllowance) {
                delete delegatedAllowance[safe][to];
            }
        }
    }
}
