using SafeHarness as safe;

methods {
    // Guardrail functions
    function DELAY() external returns (uint256) envfree;
    function immediateDelegateAllowance(address, bool) external;
    function checkTransaction(address to, uint256, bytes data, Enum.Operation operation, uint256, uint256, uint256, address, address, bytes, address) external;
    function emptyBytes() external returns (bytes) envfree;

    // Guardrail Harness functions    
    function getRemovalSchedule(address) external returns (uint256) envfree;
    function getDelegatedAllowanceOneTimeBool(address, address) external returns (bool) envfree;
    function getDelegatedAllowanceTimestamp(address, address) external returns (uint248) envfree;
    function decodeSelectorProperly(bytes) external returns (bool) envfree;
    function isMultiSendCallData(bytes) external returns (bool) envfree;

    // Safe Harness functions
    function safe.getTxGuardAddress() external returns (address) envfree;
    function safe.getModuleGuardAddress() external returns (address) envfree;

    // Use a DISPATCHER(true) here to only consider known contracts
    function _.getStorageAt(uint256, uint256) external => DISPATCHER(true);
}

// Ghost variable that tracks the last timestamp.
ghost mathint lastTimestamp {
    init_state axiom lastTimestamp > 0;
}

// The maximum timestamp the protocol supports
definition MAX_TIMESTAMP() returns mathint = max_uint248 - DELAY();

// This is to ensure that the timestamp is always in the future
// and is not decreased, not zero or max timestamp.
hook TIMESTAMP uint256 time {
    require time < MAX_TIMESTAMP();
    require time > 0;
    require time >= lastTimestamp;
    lastTimestamp = time;
}

// A helper function to require that the current contract is the tx and module guard
function requireCurrentContractAsGuard() {
    address txGuard = safe.getTxGuardAddress();
    address moduleGuard = safe.getModuleGuardAddress();
    require txGuard == moduleGuard && txGuard == currentContract;
}

// A helper function to require that no value is sent in the transaction
// and the sender is the safe address.
function requireSetup(env e) {
    require e.msg.value == 0;
    require e.msg.sender == safe;    
}

// Invariants: The timestamp of the delegate allowance should not be higher than the current timestamp + DELAY
// This is to ensure that the delegate can be used after DELAY from the current timestamp
invariant timestampNotInFutureForDelegate(address anySafe, address anyDelegate)
    getDelegatedAllowanceTimestamp(anySafe, anyDelegate) <= lastTimestamp + DELAY()
    filtered {
        f -> f.selector != sig:currentContract.multiSend(bytes).selector &&
        f.selector != sig:currentContract.multiSendNoValue(bytes).selector
    }

// Invariants: The removal schedule should not be higher than the current timestamp + DELAY
// This is to ensure that the guard can be removed after DELAY from the current timestamp
invariant timestampNotInFutureForGuard(address anySafe)
    getRemovalSchedule(anySafe) <= lastTimestamp + DELAY()
    filtered {
        f -> f.selector != sig:currentContract.multiSend(bytes).selector &&
        f.selector != sig:currentContract.multiSendNoValue(bytes).selector
    }

// Rule: Guard should be removed/changed if the removal schedule is zeroed out
rule guardRemovalWithSchedule(env e, method f, calldataarg args) filtered {
    f -> f.selector != sig:currentContract.immediateDelegateAllowance(address,bool).selector
} {
    require e.msg.value == 0;
    requireCurrentContractAsGuard();

    uint256 removalTime = getRemovalSchedule(safe);

    f(e, args);

    assert removalTime > 0 && getRemovalSchedule(safe) == 0 => safe.getTxGuardAddress() != currentContract && safe.getModuleGuardAddress() != currentContract;
}

// Rule: Immediate Delegation is only allowed if the guard is not set in the Safe
rule immediateDelegationAllowance(env e, address delegate, bool oneTime) {
    requireSetup(e);

    immediateDelegateAllowance(e, delegate, oneTime);

    assert safe.getTxGuardAddress() == 0 &&
        safe.getModuleGuardAddress() == 0 &&
        getDelegatedAllowanceOneTimeBool(safe, delegate) == oneTime &&
        getDelegatedAllowanceTimestamp(safe, delegate) == e.block.timestamp;
}

// Rule: A Safe can schedule delegate allowance always
rule scheduledDelegationAllowance(env e, address delegate, bool oneTime, bool reset) {
    requireSetup(e);

    delegateAllowance@withrevert(e, delegate, oneTime, reset);

    assert !lastReverted;
}

// Rule: A Safe can add a new delegate only after DELAY if the guard is set
rule addDelegateAfterDelay(env e, address delegate, bool oneTime) {
    requireSetup(e);

    delegateAllowance(e, delegate, oneTime, false); // reset is false explicitly

    assert getDelegatedAllowanceOneTimeBool(safe, delegate) == oneTime && getDelegatedAllowanceTimestamp(safe, delegate) == e.block.timestamp + DELAY();
}

// Rule: A Safe can always remove a delegate
rule removeDelegate(env e, address delegate, bool oneTime) {
    requireSetup(e);

    delegateAllowance(e, delegate, oneTime, true); // reset is true explicitly

    assert getDelegatedAllowanceOneTimeBool(safe, delegate) == false && getDelegatedAllowanceTimestamp(safe, delegate) == 0;
}

// Rule: If the delegate call is to Guardrail itself and the call is a MultiSendCallOnly (v1/v2) it should always be allowed
rule multiSendCallAllowedAlways(env e, uint256 value, bytes data, uint256 safeTxGas, uint256 baseGas, uint256 gasPrice, address gasToken, address refundReceiver, bytes signature, address msgSender) {
    requireSetup(e);
    requireCurrentContractAsGuard();
    require isMultiSendCallData(data);

    // Allow MultiSendCallOnly calls
    checkTransaction@withrevert(e, currentContract, value, data, Enum.Operation.DelegateCall, safeTxGas, baseGas, gasPrice, gasToken, refundReceiver, signature, msgSender);

    assert !lastReverted;
}

// Rule: All allowed delegate call (including MultiSendCallOnlyv1/v2 within Guardrail) is allowed always. All the other delegate calls should revert always
rule allowedDelegateCall(env e, address to, uint256 value, bytes data, uint256 safeTxGas, uint256 baseGas, uint256 gasPrice, address gasToken, address refundReceiver, bytes signature, address msgSender) {
    requireSetup(e);
    requireCurrentContractAsGuard();

    bool isOneTimeDelegate = getDelegatedAllowanceOneTimeBool(safe, to);
    bool allowanceBefore = (getDelegatedAllowanceTimestamp(safe, to) > 0 && getDelegatedAllowanceTimestamp(safe, to) < e.block.timestamp);

    // Allow delegate calls to Guardrail itself & allowed delegates
    checkTransaction@withrevert(e, to, value, data, Enum.Operation.DelegateCall, safeTxGas, baseGas, gasPrice, gasToken, refundReceiver, signature, msgSender);
    bool success = !lastReverted;

    assert success <=>
        decodeSelectorProperly(data) &&
        (
            (to == currentContract && isMultiSendCallData(data)) ||
            (
                (getDelegatedAllowanceTimestamp(safe, to) > 0 && getDelegatedAllowanceTimestamp(safe, to) < e.block.timestamp) ||
                (isOneTimeDelegate && allowanceBefore)
            )
        );
}

// Rule: It should not be possible to decrease the timestamp of the delegate allowance
rule delegateAllowanceTimestampNotDecreased(env e, address delegate, calldataarg args, method f) filtered {
    f -> f.selector != sig:currentContract.immediateDelegateAllowance(address,bool).selector
} {
    requireSetup(e);
    requireCurrentContractAsGuard();
    requireInvariant timestampNotInFutureForDelegate(safe, delegate);

    uint248 oldTimestamp = getDelegatedAllowanceTimestamp(safe, delegate);

    f(e, args);

    assert getDelegatedAllowanceTimestamp(safe, delegate) >= oldTimestamp || getDelegatedAllowanceTimestamp(safe, delegate) == 0;
}

// Rule: It should not be possible to decrease the removal schedule timestamp
rule removalScheduleTimestampNotDecreased(env e, calldataarg args, method f) filtered {
    f -> f.selector != sig:currentContract.immediateDelegateAllowance(address,bool).selector
} {
    requireSetup(e);
    requireCurrentContractAsGuard();
    requireInvariant timestampNotInFutureForGuard(safe);

    uint256 oldRemovalSchedule = getRemovalSchedule(safe);

    f(e, args);

    assert getRemovalSchedule(safe) >= oldRemovalSchedule || getRemovalSchedule(safe) == 0;
}
