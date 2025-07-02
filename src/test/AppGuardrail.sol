// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity =0.8.28;

import {Guardrail, Enum, MultiSendCallOnly, MultiSendCallOnlyv2} from "../Guardrail.sol";
import {SafeInterface} from "../interfaces/SafeInterface.sol";
import {ITransactionGuard} from "safe-smart-account/contracts/base/GuardManager.sol";
import {IModuleGuard} from "safe-smart-account/contracts/base/ModuleManager.sol";
import {EnumerableSet} from "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";

contract AppGuardrail is Guardrail {
    using EnumerableSet for EnumerableSet.AddressSet;

    mapping(address => EnumerableSet.AddressSet) private delegates;

    /**
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
     *      This will allow the delegate call if the {to} is the guard contract itself (for MultiSendCallOnly functionality)
     *      This will also remove from the delegates list if it is a one time allowance.
     */
    function _checkOperationAndAllowance(address safe, address to, bytes4 selector, Enum.Operation operation)
        internal override
    {
        if (
            to == address(this)
                && (
                    selector == MultiSendCallOnly.multiSend.selector
                        || selector == MultiSendCallOnlyv2.multiSendNoValue.selector
                )
        ) {
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
                delegates[safe].remove(to);
            }
        }
    }

    /**
     * @notice This function is called after the execution of a transaction to check if the guard is set up correctly.
     * @dev This function only checks the Tx Guard and not the Module Guard. This is done for v1.4.1 Wallet Interface compatibility.
     */
    function _checkAfterExecution() internal override {
        SafeInterface safe = SafeInterface(msg.sender);
        address guard = abi.decode(safe.getStorageAt(GUARD_STORAGE_SLOT, 1), (address));

        // Higher chance of this being true, so added the check first as a circuit breaker
        if (guard == address(this)) {
            return;
        } else {
            _removeGuard();
        }
    }

    /**
     * @notice Internal function to set the delegate allowance
     * @param safe The address of the safe
     * @param to The address of the delegate
     * @param timestamp The timestamp at which the delegate is allowed
     * @param oneTimeAllowance The status of the one time allowance
     * @dev This will emit the DelegateAllowanceUpdated event
     *      This has an additional delegates set to read all the delegated allowances in UI easily
     */
    function _delegateAllowance(address safe, address to, bool oneTimeAllowance, uint256 timestamp) internal override {
        delegatedAllowance[safe][to] = Allowance(oneTimeAllowance, uint248(timestamp));
        delegates[safe].add(to);

        emit DelegateAllowanceUpdated(safe, to, oneTimeAllowance, timestamp);
    }

    /**
     * @notice Function to update the delegate allowance
     * @param to The address of the delegate
     * @param oneTimeAllowance The status of the one time allowance
     * @param reset true if the delegate allowance should be reset
     * @dev This will fail if the delegate allowance is not scheduled
     *      This has an additional delegates removal to read all the delegated allowances in UI easily
     */
    function delegateAllowance(address to, bool oneTimeAllowance, bool reset) public override {
        if (reset) {
            delete delegatedAllowance[msg.sender][to];
            delegates[msg.sender].remove(to);
        } else {
            _delegateAllowance(msg.sender, to, oneTimeAllowance, DELAY + block.timestamp);
        }
    }

    /**
     * @notice Function to get all the delegates for an account
     * @param account The address of the account to check
     * @return An array of addresses that are delegates for the account
     */
    function getDelegates(address account) external view returns (address[] memory) {
        return delegates[account].values();
    }
}
