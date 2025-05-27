using SafeHarness as safe;

methods {
    // Guardrail functions
    function DELAY() external returns (uint256) envfree;

    // Guardrail Harness functions    
    function getRemovalSchedule(address) external returns (uint256) envfree;

    // Safe functions
    function safe.setGuard(address) external returns (bool);

    // Safe Harness functions
    function safe.getGuardAddress() external returns (address) envfree;
}

// Rule: Guard removal is only allowed after DELAY
// The guard can only be removed after the delay period has passed
// This rule ensures that the guard cannot be removed immediately, providing a safety net
// for the Safe's operations.
rule guardRemovalAfterDelayOnly(env e, method f, calldataarg args) {
    require e.msg.value == 0;
    require e.msg.sender == safe;
    require e.block.timestamp + DELAY() < max_uint256;

    uint256 removalTimestamp = getRemovalSchedule(safe);
    require safe.getGuardAddress() == currentContract;

    f(e, args);

    assert safe.getGuardAddress() == 0
        => removalTimestamp > 0 && removalTimestamp <= e.block.timestamp && getRemovalSchedule(safe) == 0;
}

// Rule: Guard removal without schedule should always revert
// Rule: Immediate Delegation is only allowed if the guard is not set in the Safe
// Rule: A Safe can schedule delegate allowance always
// Rule: A Safe can add a new delegate only after DELAY if the guard is set
// Rule: A Safe can always remove a delegate
// Rule: If the delegate call is to Guardrail itself and the call is a MultiSendCallOnly (v1/v2) it should always be allowed
// Rule: All allowed delegate call (including MultiSendCallOnlyv1/v2 within Guardrail) is allowed always
// Rule: All the other delegate calls should revert always
