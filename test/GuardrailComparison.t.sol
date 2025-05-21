// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity =0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {Guardrail} from "../src/Guardrail.sol";
import {GuardrailWithMultisend} from "../src/GuardrailWithMultisend.sol";
import {Enum, Safe, SafeL2} from "safe-smart-account/contracts/SafeL2.sol";
import {SafeProxyFactory} from "safe-smart-account/contracts/proxies/SafeProxyFactory.sol";
import {SafeProxy} from "safe-smart-account/contracts/proxies/SafeProxy.sol";
import {MultiSendCallOnly} from "safe-smart-account/contracts/libraries/MultiSendCallOnly.sol";
import {ERC20Token} from "safe-smart-account/contracts/test/ERC20Token.sol";

contract GuardrailTest is Test {
    uint256 private constant DELAY = 7 days;

    /**
     * @notice The storage slot for the guard
     * @dev This is used to check if the guard is set
     *      Value = `keccak256("guard_manager.guard.address")`
     */
    bytes32 private constant GUARD_STORAGE_SLOT = 0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8;

    // Owner structure
    address private owner;
    uint256 private ownerPrivateKey;
    address[] private owners = new address[](1);

    // Safe threshold
    uint256 private threshold = 1;

    // Contract instances
    Guardrail private guardrail;
    GuardrailWithMultisend private guardrailWithMultisend;
    MultiSendCallOnly private multiSendCallOnly;
    ERC20Token private erc20Token;
    address private singleton;
    SafeL2 private safe;
    SafeProxyFactory private safeProxyFactory;
    uint256 private salt;

    // Empty bytes and address
    bytes private emptyBytes = "";
    address private zeroAddress = address(0);
    address payable private payableZeroAddress = payable(zeroAddress);

    // Dummy data
    address private randomAddress1;
    address private randomAddress2;
    address private randomAddress3;

    // Helper function to get the executor signature
    function getExecutorSignature(address ownerAddress) private pure returns (bytes memory) {
        return abi.encodePacked(abi.encode(ownerAddress), bytes32(0), uint8(1));
    }

    // Function to get the setup data for the Safe contract
    function getSetupData() private view returns (bytes memory) {
        return abi.encodeWithSelector(
            Safe.setup.selector,
            owners,
            threshold,
            zeroAddress,
            emptyBytes,
            zeroAddress,
            zeroAddress,
            0,
            payableZeroAddress
        );
    }

    // Function to set up the owners
    function setupOwners() private {
        (owner, ownerPrivateKey) = makeAddrAndKey("owner");
        owners = [owner];
    }

    // Function to set up the guardrail contract
    function setupGuardrail() private {
        guardrail = new Guardrail(DELAY);
    }

    // Function to set up GuardrailWithMultisend contract
    function setupGuardrailWithMultisend() private {
        guardrailWithMultisend = new GuardrailWithMultisend(DELAY);
    }

    // Function to set up the MultiSendCallOnly contract
    function setupMultiSendCallOnly() private {
        multiSendCallOnly = new MultiSendCallOnly();
    }

    // Function to set up the ERC20 token contract
    function setupERC20Token() private {
        vm.prank(owner);
        erc20Token = new ERC20Token();
    }

    // Function to set up the Safe contract
    function setupSafe() private {
        singleton = address(new SafeL2());
        safeProxyFactory = new SafeProxyFactory();
        bytes memory setupData = getSetupData();

        salt++;
        safe = SafeL2(payable(safeProxyFactory.createProxyWithNonce(singleton, setupData, salt)));
    }

    // Function to set up dummy data for testing
    function setupMultiSendTxData() private returns (bytes memory multiSendTxs) {
        // Random generated addresses for the test
        randomAddress1 = makeAddr("randomAddress1");
        randomAddress2 = makeAddr("randomAddress2");
        randomAddress3 = makeAddr("randomAddress3");

        // Set some value to safe address
        vm.deal(address(safe), 10 ether);
        vm.prank(owner);
        erc20Token.transfer(address(safe), 1e10);

        bytes[] memory txs = new bytes[](3);

        // Transfer 1 ETH to randomAddress1
        txs[0] = abi.encodePacked(
            uint8(0), // Operation: Call
            randomAddress1, // Address to send to
            uint256(1 ether), // Value to send
            emptyBytes.length,
            emptyBytes // Data
        );

        // Transfer 1e10 ERC20 Token to randomAddress2
        bytes memory erc20TxData = abi.encodeWithSelector(erc20Token.transfer.selector, randomAddress2, 1e10);
        txs[1] = abi.encodePacked(
            uint8(0), // Operation: Call
            randomAddress2, // Address to send to
            uint256(0), // Value to send
            erc20TxData.length,
            erc20TxData // Data
        );

        // Add randomAddress3 as an owner to the Safe contract
        bytes memory addOwnerData =
            abi.encodeWithSelector(safe.addOwnerWithThreshold.selector, randomAddress3, threshold);
        txs[2] = abi.encodePacked(
            uint8(0), // Operation: Call
            address(safe), // Address to send to
            uint256(0), // Value to send
            addOwnerData.length,
            addOwnerData // Data
        );

        // Encode the transactions
        bytes memory transactions;
        for (uint256 i = 0; i < txs.length; i++) {
            transactions = abi.encodePacked(transactions, txs[i]);
        }

        multiSendTxs = abi.encodeWithSelector(multiSendCallOnly.multiSend.selector, transactions);
    }

    // Function to set up the test environment
    function setUp() public {
        setupOwners();
        setupGuardrail();
        setupGuardrailWithMultisend();
        setupERC20Token();
        setupMultiSendCallOnly();
        setupSafe();
    }

    // Function to test the gas usage of the Guardrail contract for MultiSendCallOnly transactions
    function testGuardrailGasUsage() public {
        // Using MultiSendCallOnly to immediately set the delegate (MultiSendCallOnly) and set the guard
        bytes[] memory txs = new bytes[](2);

        bytes memory setupDelegateData =
            abi.encodeWithSelector(guardrail.immediateDelegateAllowance.selector, address(multiSendCallOnly), false);
        txs[0] = abi.encodePacked(
            uint8(0), // Operation: Call
            address(guardrail), // Address to send to
            uint256(0), // Value to send
            setupDelegateData.length,
            setupDelegateData // Data
        );

        bytes memory setupGuardData = abi.encodeWithSelector(safe.setGuard.selector, address(guardrail));
        txs[1] = abi.encodePacked(
            uint8(0), // Operation: Call
            address(safe), // Address to send to
            uint256(0), // Value to send
            setupGuardData.length,
            setupGuardData // Data
        );

        bytes memory setupDelegateAndGuardData = abi.encodePacked(txs[0], txs[1]);

        bytes memory setupDelegateAndGuardMultisend =
            abi.encodeWithSelector(multiSendCallOnly.multiSend.selector, setupDelegateAndGuardData);

        vm.prank(owner);
        safe.execTransaction(
            address(multiSendCallOnly),
            0,
            setupDelegateAndGuardMultisend,
            Enum.Operation.DelegateCall,
            0,
            0,
            0,
            zeroAddress,
            payableZeroAddress,
            getExecutorSignature(owner)
        );
        vm.snapshotGasLastCall("Guardrail Setup (using MultiSendCallOnly)");

        // Moving to the next block and timestamp
        vm.roll(vm.getBlockNumber() + 1);
        vm.warp(vm.getBlockTimestamp() + 1);

        // Setting up MultiSendCallOnly transactions
        bytes memory multiSendTxs = setupMultiSendTxData();

        // Executing the transaction.
        vm.prank(owner);
        safe.execTransaction(
            address(multiSendCallOnly),
            0,
            multiSendTxs,
            Enum.Operation.DelegateCall,
            0,
            0,
            0,
            zeroAddress,
            payableZeroAddress,
            getExecutorSignature(owner)
        );
        vm.snapshotGasLastCall("Guardrail MultiSend Tx");
    }

    // Function to test the gas usage of the GuardrailWithMultisend contract for MultiSendCallOnly transactions
    function testGuardrailWithMultisendGasUsage() public {
        // Setup the guardrailWithMultisend contract
        bytes memory setupGuardData = abi.encodeWithSelector(safe.setGuard.selector, address(guardrailWithMultisend));

        vm.prank(owner);
        safe.execTransaction(
            address(safe),
            0,
            setupGuardData,
            Enum.Operation.Call,
            0,
            0,
            0,
            zeroAddress,
            payableZeroAddress,
            getExecutorSignature(owner)
        );
        vm.snapshotGasLastCall("GuardrailWithMultisend Setup");

        // Moving to the next block and timestamp
        vm.roll(vm.getBlockNumber() + 1);
        vm.warp(vm.getBlockTimestamp() + 1);

        // Setting up MultiSendCallOnly transactions
        bytes memory multiSendTxs = setupMultiSendTxData();

        // Executing the transaction.
        vm.prank(owner);
        safe.execTransaction(
            address(guardrailWithMultisend),
            0,
            multiSendTxs,
            Enum.Operation.DelegateCall,
            0,
            0,
            0,
            zeroAddress,
            payableZeroAddress,
            getExecutorSignature(owner)
        );
        vm.snapshotGasLastCall("GuardrailWithMultisend MultiSend Tx");
    }
}
