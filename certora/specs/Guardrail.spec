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

function requireCurrentContractAsGuard() {
    address txGuard = safe.getTxGuardAddress();
    address moduleGuard = safe.getModuleGuardAddress();
    require txGuard == moduleGuard && txGuard == currentContract;
}

function requireSetup(env e) {
    require e.msg.value == 0;
    require currentContract != safe;
    require e.msg.sender == safe;    
}

// Rule: Guard removal without schedule should always revert
rule guardRemovalWithoutSchedule(env e, method f, calldataarg args) {
    require e.msg.value == 0;
    require currentContract != safe;
    require e.block.timestamp > 0;
    requireCurrentContractAsGuard();

    uint256 removalTime = getRemovalSchedule(safe);

    f@withrevert(e, args);

    assert removalTime > 0 && getRemovalSchedule(safe) == 0 => safe.getTxGuardAddress() != currentContract && safe.getModuleGuardAddress() != currentContract;
}

// Rule: Immediate Delegation is only allowed if the guard is not set in the Safe
rule immediateDelegationAllowance(env e, address delegate, bool allow) {
    requireSetup(e);
    require e.block.timestamp > 0 && e.block.timestamp < max_uint248;

    immediateDelegateAllowance@withrevert(e, delegate, allow);

    assert !lastReverted =>
        safe.getTxGuardAddress() == 0 &&
        safe.getModuleGuardAddress() == 0 &&
        getDelegatedAllowanceOneTimeBool(safe, delegate) == allow &&
        getDelegatedAllowanceTimestamp(safe, delegate) == e.block.timestamp;
}

// Rule: A Safe can schedule delegate allowance always
rule scheduledDelegationAllowance(env e, address delegate, bool allow, bool reset) {
    requireSetup(e);
    require e.block.timestamp > 0 && e.block.timestamp + DELAY() < max_uint248;

    delegateAllowance@withrevert(e, delegate, allow, reset);

    assert !lastReverted;
}

// Rule: A Safe can add a new delegate only after DELAY if the guard is set
rule addDelegateAfterDelay(env e, address delegate, bool allow) {
    requireSetup(e);
    require e.block.timestamp > 0 && e.block.timestamp + DELAY() < max_uint248;

    delegateAllowance@withrevert(e, delegate, allow, false); // reset is false explicitly

    assert getDelegatedAllowanceOneTimeBool(safe, delegate) == allow && getDelegatedAllowanceTimestamp(safe, delegate) == e.block.timestamp + DELAY();
}

// Rule: A Safe can always remove a delegate
rule removeDelegate(env e, address delegate) {
    requireSetup(e);

    delegateAllowance@withrevert(e, delegate, false, true); // reset is true explicitly

    assert !lastReverted && getDelegatedAllowanceOneTimeBool(safe, delegate) == false && getDelegatedAllowanceTimestamp(safe, delegate) == 0;
}

// Rule: If the delegate call is to Guardrail itself and the call is a MultiSendCallOnly (v1/v2) it should always be allowed
rule multiSendCallAllowedAlways(env e, bytes data) {
    requireSetup(e);
    requireCurrentContractAsGuard();
    require isMultiSendCallData(data);

    // Allow MultiSendCallOnly calls
    checkTransaction@withrevert(e, currentContract, 0, data, Enum.Operation.DelegateCall, 0, 0, 0, 0, 0, emptyBytes(), 0);

    assert !lastReverted;
}

// Rule: All allowed delegate call (including MultiSendCallOnlyv1/v2 within Guardrail) is allowed always. All the other delegate calls should revert always
rule allowedDelegateCall(env e, address to, bytes data) {
    requireSetup(e);
    requireCurrentContractAsGuard();

    bool isOneTimeDelegate = getDelegatedAllowanceOneTimeBool(safe, to);

    // Allow delegate calls to Guardrail itself & allowed delegates
    checkTransaction@withrevert(e, to, 0, data, Enum.Operation.DelegateCall, 0, 0, 0, 0, 0, emptyBytes(), 0);
    bool success = !lastReverted;

    assert success =>
        decodeSelectorProperly(data) &&
        (
            (to == currentContract && isMultiSendCallData(data)) ||
            (
                (getDelegatedAllowanceTimestamp(safe, to) > 0 && getDelegatedAllowanceTimestamp(safe, to) <= e.block.timestamp) ||
                isOneTimeDelegate
            )
        );
    assert !success =>
        !decodeSelectorProperly(data) ||
        (
            (to != currentContract || !isMultiSendCallData(data)) ||
            (getDelegatedAllowanceTimestamp(safe, to) == 0 && getDelegatedAllowanceTimestamp(safe, to) > e.block.timestamp)
        );
}
