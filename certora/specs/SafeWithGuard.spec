using GuardrailHarness as guardrail;

methods {
    // SafeHarness functions
    function getTxGuardAddress() external returns (address) envfree;
    function getModuleGuardAddress() external returns (address) envfree;

    // Guardrail functions
    function guardrail.checkTransaction(address to, uint256, bytes data, Enum.Operation operation, uint256, uint256, uint256, address, address, bytes, address) external => checkTransactionSummary(to, data, operation);

    // The false means not-optimistic, i.e., the prover checks that the call is really to one of the contracts in the scene.
    function _.checkTransaction(address to, uint256, bytes data, Enum.Operation operation, uint256, uint256, uint256, address, address, bytes, address) external => DISPATCHER(false);
}

function checkTransactionSummary(address to, bytes data, Enum.Operation operation) {
    checkTransactionCalled = true;
    // Save all the arguments to check within the DELEGATECALL hook
    checkTransactionSummaryTo = to;
    checkTransactionSummaryDataLength = data.length;
    checkTransactionSummaryOperation = operation;
}

ghost bool checkTransactionCalled;
ghost address checkTransactionSummaryTo;
ghost mathint checkTransactionSummaryDataLength;
ghost Enum.Operation checkTransactionSummaryOperation;

hook DELEGATECALL(uint g, address addr, uint argsOffset, uint argsLength, uint retOffset, uint retLength) uint rc {
    // This hook is used to track calls to checkTransaction
    assert checkTransactionCalled;
    assert addr == checkTransactionSummaryTo;
    assert argsLength == checkTransactionSummaryDataLength;
    assert Enum.Operation.DelegateCall == checkTransactionSummaryOperation;
    checkTransactionCalled = false; // Reset the flag after the call
}

// Rule: `checkTransaction` should always be called in a safe with a guard
rule checkTransactionCalledAlways(env e, method f, calldataarg args) filtered {
    f -> f.selector != sig:currentContract.setup(address[], uint256, address, bytes, address, address, uint256, address).selector &&
        f.selector != sig:currentContract.simulateAndRevert(address,bytes).selector &&
        f.selector != sig:currentContract.execTransactionFromModule(address,uint256,bytes,Enum.Operation).selector &&
        f.selector != sig:currentContract.execTransactionFromModuleReturnData(address,uint256,bytes,Enum.Operation).selector
} {
    require e.msg.value == 0;
    require e.msg.sender == currentContract;

    address txGuard = getTxGuardAddress();
    address moduleGuard = getModuleGuardAddress();
    require txGuard == moduleGuard && txGuard == guardrail;

    // Check if the checkTransaction function was called
    f(e, args);

    assert true;
}
