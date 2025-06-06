// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity =0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {Enum, Safe, SafeL2} from "safe-smart-account/contracts/SafeL2.sol";
import {SafeProxyFactory} from "safe-smart-account/contracts/proxies/SafeProxyFactory.sol";
import {SafeProxy} from "safe-smart-account/contracts/proxies/SafeProxy.sol";
import {ERC20Token} from "safe-smart-account/contracts/test/ERC20Token.sol";
import {Guardrail, MultiSendCallOnlyv2, MultiSendCallOnly} from "../src/Guardrail.sol";
import {MockModule} from "../src/test/MockModule.sol";

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
    address[] private randomAddresses;

    ////////////////////////////
    // ** HELPER FUNCTIONS ** //
    ////////////////////////////

    // Helper function to get the executor signature
    function getExecutorSignature(address ownerAddress) private pure returns (bytes memory) {
        return abi.encodePacked(abi.encode(ownerAddress), bytes32(0), uint8(1));
    }

    // Helper Function to set the guard in the Safe contract
    function setupGuard() private {
        // Setting up the transaction guard.
        bytes memory guardSetupData = abi.encodeWithSelector(safe.setGuard.selector, address(guardrail));

        // Setting up the module guard.
        bytes memory moduleGuardSetupData = abi.encodeWithSelector(safe.setModuleGuard.selector, address(guardrail));

        bytes[] memory txs = new bytes[](2);

        // Transaction guard setup
        txs[0] = abi.encodePacked(
            uint8(0), // Operation: Call
            address(safe), // Address to interact with
            uint256(0), // Value to send
            guardSetupData.length,
            guardSetupData // Data
        );

        // Module guard setup
        txs[1] = abi.encodePacked(
            uint8(0), // Operation: Call
            address(safe), // Address to interact with
            uint256(0), // Value to send
            moduleGuardSetupData.length,
            moduleGuardSetupData // Data
        );

        bytes memory transactions;
        for (uint256 i = 0; i < txs.length; i++) {
            transactions = abi.encodePacked(transactions, txs[i]);
        }

        bytes memory multiSendTxs = abi.encodeWithSelector(MultiSendCallOnly.multiSend.selector, transactions);

        // Executing the transaction.
        vm.prank(owner);
        safe.execTransaction(
            address(guardrail),
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
    }

    // Helper Function to remove the guard in the Safe contract
    function removeGuardData() private view returns (bytes memory multiSendTxs) {
        // Setting up the transaction guard to zero address.
        bytes memory guardRemoveData = abi.encodeWithSelector(safe.setGuard.selector, zeroAddress);

        // Setting up the module guard to zero address.
        bytes memory moduleGuardRemoveData = abi.encodeWithSelector(safe.setModuleGuard.selector, zeroAddress);

        bytes[] memory txs = new bytes[](2);

        // Transaction guard removal
        txs[0] = abi.encodePacked(
            uint8(0), // Operation: Call
            address(safe), // Address to interact with
            uint256(0), // Value to send
            guardRemoveData.length,
            guardRemoveData // Data
        );

        // Module guard removal
        txs[1] = abi.encodePacked(
            uint8(0), // Operation: Call
            address(safe), // Address to interact with
            uint256(0), // Value to send
            moduleGuardRemoveData.length,
            moduleGuardRemoveData // Data
        );

        bytes memory transactions;
        for (uint256 i = 0; i < txs.length; i++) {
            transactions = abi.encodePacked(transactions, txs[i]);
        }

        multiSendTxs = abi.encodeWithSelector(MultiSendCallOnly.multiSend.selector, transactions);
    }

    // Helper Function to create a random address
    function createRandomAddresses(uint256 count) private {
        randomAddresses = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            randomAddresses[i] = makeAddr(string(abi.encodePacked("randomAddress", i)));
        }
    }

    // Helper Function to set up dummy data for testing MultiSendCallOnly transactions
    function setupMultiSendTxData() private returns (bytes memory multiSendTxs) {
        // Random generated addresses for the test
        createRandomAddresses(3);

        // Set some value to safe address
        vm.deal(address(safe), 10 ether);
        vm.prank(owner);
        erc20Token.transfer(address(safe), 1e10);

        bytes[] memory txs = new bytes[](3);

        // Transfer 1 ETH to randomAddress 1
        txs[0] = abi.encodePacked(
            uint8(0), // Operation: Call
            randomAddresses[0], // Address to send to
            uint256(1 ether), // Value to send
            emptyBytes.length,
            emptyBytes // Data
        );

        // Transfer 1e10 ERC20 Token to randomAddress 2
        bytes memory erc20TxData = abi.encodeWithSelector(erc20Token.transfer.selector, randomAddresses[1], 1e10);
        txs[1] = abi.encodePacked(
            uint8(0), // Operation: Call
            address(erc20Token), // Address to interact with
            uint256(0), // Value to send
            erc20TxData.length,
            erc20TxData // Data
        );

        // Add randomAddress 3 as an owner to the Safe contract
        bytes memory addOwnerData =
            abi.encodeWithSelector(safe.addOwnerWithThreshold.selector, randomAddresses[2], threshold);
        txs[2] = abi.encodePacked(
            uint8(0), // Operation: Call
            address(safe), // Address to interact with
            uint256(0), // Value to send
            addOwnerData.length,
            addOwnerData // Data
        );

        // Encode the transactions
        bytes memory transactions;
        for (uint256 i = 0; i < txs.length; i++) {
            transactions = abi.encodePacked(transactions, txs[i]);
        }

        multiSendTxs = abi.encodeWithSelector(MultiSendCallOnly.multiSend.selector, transactions);
    }

    // Helper Function to set up dummy data for testing MultiSendCallOnlyv2 transactions
    function setupMultiSendv2TxData() private returns (bytes memory multiSendTxs) {
        // Random generated addresses for the test
        createRandomAddresses(3);

        // Set some value to safe address
        vm.deal(address(safe), 10 ether);
        vm.prank(owner);
        erc20Token.transfer(address(safe), 1e15);

        bytes[] memory txs = new bytes[](3);

        // Transfer 1e5 ERC20 Token to randomAddress 1
        bytes memory erc20TxData = abi.encodeWithSelector(erc20Token.transfer.selector, randomAddresses[0], 1e5);
        txs[0] = abi.encodePacked(
            address(erc20Token), // Address to interact with
            erc20TxData.length,
            erc20TxData // Data
        );

        // Transfer 1e10 ERC20 Token to randomAddress 2
        erc20TxData = abi.encodeWithSelector(erc20Token.transfer.selector, randomAddresses[1], 1e10);
        txs[1] = abi.encodePacked(
            address(erc20Token), // Address to interact with
            erc20TxData.length,
            erc20TxData // Data
        );

        // Add randomAddress 3 as an owner to the Safe contract
        bytes memory addOwnerData =
            abi.encodeWithSelector(safe.addOwnerWithThreshold.selector, randomAddresses[2], threshold);
        txs[2] = abi.encodePacked(
            address(safe), // Address to interact with
            addOwnerData.length,
            addOwnerData // Data
        );

        // Encode the transactions
        bytes memory transactions;
        for (uint256 i = 0; i < txs.length; i++) {
            transactions = abi.encodePacked(transactions, txs[i]);
        }

        multiSendTxs = abi.encodeWithSelector(MultiSendCallOnlyv2.multiSendNoValue.selector, transactions);
    }

    ////////////////////////////
    // ** SETUP FUNCTIONS ** //
    ////////////////////////////

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

    // Function to set up the test environment
    function setUp() public {
        setupOwners();
        setupGuardrail();
        setupERC20Token();
        setupSafe();
    }

    ////////////////////////////
    //  ** TEST FUNCTIONS **  //
    ////////////////////////////

    // Test function to check if the guard is set correctly
    function testSettingUpGuard() public {
        // Checking if any guard is set in safe.
        assertEq(abi.decode(safe.getStorageAt(uint256(GUARD_STORAGE_SLOT), 1), (address)), zeroAddress);

        // Setting up the guard.
        setupGuard();

        // Checking if guard is set.
        assertEq(abi.decode(safe.getStorageAt(uint256(GUARD_STORAGE_SLOT), 1), (address)), address(guardrail));
    }

    // Test function to check if the guard prevents delegate calls
    function testDelegateTxAfterGuardSetup() public {
        // Setting up the guard.
        setupGuard();

        // Expect Tx to be reverted.
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(Guardrail.DelegateCallNotAllowed.selector, owner), address(guardrail));
        safe.execTransaction(
            owner, // Sending some value to the owner
            1, // Value to be sent
            emptyBytes,
            Enum.Operation.DelegateCall,
            0,
            0,
            0,
            zeroAddress,
            payableZeroAddress,
            getExecutorSignature(owner)
        );
    }

    // Test function to check the gas usage of the Guardrail contract for MultiSendCallOnly transactions
    function testMultiSendCapability() public {
        setupGuard();

        // Setting up MultiSendCallOnly transactions
        bytes memory multiSendTxs = setupMultiSendTxData();

        // Executing the transaction.
        vm.prank(owner);
        safe.execTransaction(
            address(guardrail),
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

        // Check if the transactions were executed successfully
        assertEq(payable(randomAddresses[0]).balance, 1 ether);
        assertEq(erc20Token.balanceOf(randomAddresses[1]), 1e10);
        assertEq(safe.isOwner(randomAddresses[2]), true);
        assertEq(safe.getOwners().length, 2);
    }

    // Test function to check the gas usage of the Guardrail contract for MultiSendCallOnlyv2 transactions
    function testMultiSendv2Capability() public {
        setupGuard();

        // Setting up MultiSendCallOnly transactions
        bytes memory multiSendv2Txs = setupMultiSendv2TxData();

        // Executing the transaction.
        vm.prank(owner);
        safe.execTransaction(
            address(guardrail),
            0,
            multiSendv2Txs,
            Enum.Operation.DelegateCall,
            0,
            0,
            0,
            zeroAddress,
            payableZeroAddress,
            getExecutorSignature(owner)
        );

        // Check if the transactions were executed successfully
        assertEq(erc20Token.balanceOf(randomAddresses[0]), 1e5);
        assertEq(erc20Token.balanceOf(randomAddresses[1]), 1e10);
        assertEq(safe.isOwner(randomAddresses[2]), true);
        assertEq(safe.getOwners().length, 2);
    }

    // Test function to check removal of the guard
    function testGuardRemoval() public {
        // Setting up the guard.
        setupGuard();

        // Checking if guard is set.
        assertEq(abi.decode(safe.getStorageAt(uint256(GUARD_STORAGE_SLOT), 1), (address)), address(guardrail));

        // Scheduling the removal of the guard.
        bytes memory scheduleGuardRemovalData = abi.encodeWithSelector(guardrail.scheduleGuardRemoval.selector);
        vm.prank(owner);
        safe.execTransaction(
            address(guardrail),
            0,
            scheduleGuardRemovalData,
            Enum.Operation.Call,
            0,
            0,
            0,
            zeroAddress,
            payableZeroAddress,
            getExecutorSignature(owner)
        );

        // Increasing the timestamp to pass the guard removal delay.
        vm.warp(block.timestamp + DELAY + 1);

        // Removing the guard.
        bytes memory data = removeGuardData();
        vm.prank(owner);
        safe.execTransaction(
            address(guardrail),
            0,
            data,
            Enum.Operation.DelegateCall,
            0,
            0,
            0,
            zeroAddress,
            payableZeroAddress,
            getExecutorSignature(owner)
        );

        // Checking if guard is removed.
        assertEq(abi.decode(safe.getStorageAt(uint256(GUARD_STORAGE_SLOT), 1), (address)), zeroAddress);
    }

    // Test function to check revert if the guard removal timestamp is not passed
    function testGuardRemovalTimestampRevert() public {
        // Setting up the guard.
        setupGuard();

        // Scheduling the removal of the guard.
        bytes memory scheduleGuardRemovalData = abi.encodeWithSelector(guardrail.scheduleGuardRemoval.selector);
        vm.prank(owner);
        safe.execTransaction(
            address(guardrail),
            0,
            scheduleGuardRemovalData,
            Enum.Operation.Call,
            0,
            0,
            0,
            zeroAddress,
            payableZeroAddress,
            getExecutorSignature(owner)
        );

        // Expect revert as the removal timestamp is not passed yet.
        vm.expectRevert(Guardrail.InvalidTimestamp.selector);
        // Removing the guard.
        bytes memory data = removeGuardData();
        vm.prank(owner);
        safe.execTransaction(
            address(guardrail),
            0,
            data,
            Enum.Operation.DelegateCall,
            0,
            0,
            0,
            zeroAddress,
            payableZeroAddress,
            getExecutorSignature(owner)
        );

        // Checking if guard is still set.
        assertEq(abi.decode(safe.getStorageAt(uint256(GUARD_STORAGE_SLOT), 1), (address)), address(guardrail));
    }

    // Test function to check revert if the guard removal timestamp is not passed
    function testGuardRemovalSingleRemovalRevert() public {
        // Setting up the guard.
        setupGuard();

        // Scheduling the removal of the guard.
        bytes memory scheduleGuardRemovalData = abi.encodeWithSelector(guardrail.scheduleGuardRemoval.selector);
        vm.prank(owner);
        safe.execTransaction(
            address(guardrail),
            0,
            scheduleGuardRemovalData,
            Enum.Operation.Call,
            0,
            0,
            0,
            zeroAddress,
            payableZeroAddress,
            getExecutorSignature(owner)
        );

        // Trying to remove only the Tx guard.
        // Setting up the transaction guard to zero address.
        bytes memory guardRemoveData = abi.encodeWithSelector(safe.setGuard.selector, zeroAddress);

        // Transaction guard removal
        bytes memory guardRemovalTx = abi.encodePacked(
            uint8(0), // Operation: Call
            address(safe), // Address to interact with
            uint256(0), // Value to send
            guardRemoveData.length,
            guardRemoveData // Data
        );

        bytes memory data = abi.encodeWithSelector(MultiSendCallOnly.multiSend.selector, guardRemovalTx);

        // Expect revert as only one guard is being removed.
        vm.expectRevert(Guardrail.ImproperGuardSetup.selector);
        vm.prank(owner);
        safe.execTransaction(
            address(guardrail),
            0,
            data,
            Enum.Operation.DelegateCall,
            0,
            0,
            0,
            zeroAddress,
            payableZeroAddress,
            getExecutorSignature(owner)
        );

        // Checking if guard is still set.
        assertEq(abi.decode(safe.getStorageAt(uint256(GUARD_STORAGE_SLOT), 1), (address)), address(guardrail));
    }

    // Test function to check the event emitted on guard removal
    function testGuardRemovalScheduleEvent() public {
        // Setting up the guard.
        setupGuard();

        // Scheduling the removal of the guard.
        bytes memory scheduleGuardRemovalData = abi.encodeWithSelector(guardrail.scheduleGuardRemoval.selector);
        vm.prank(owner);
        vm.expectEmit(true, true, false, true, address(guardrail));
        emit Guardrail.GuardRemovalScheduled(address(safe), DELAY + block.timestamp);
        safe.execTransaction(
            address(guardrail),
            0,
            scheduleGuardRemovalData,
            Enum.Operation.Call,
            0,
            0,
            0,
            zeroAddress,
            payableZeroAddress,
            getExecutorSignature(owner)
        );
    }

    // Test function to check immediate setting of the delegates in guardrail
    function testImmediateDelegateAllowance() public {
        // Create a random address for the delegate.
        createRandomAddresses(1);

        // Setting the delegate allowance immediately.
        vm.prank(owner);
        bytes memory immediateDelegateAllowanceData =
            abi.encodeWithSelector(guardrail.immediateDelegateAllowance.selector, randomAddresses[0], true);
        safe.execTransaction(
            address(guardrail),
            0,
            immediateDelegateAllowanceData,
            Enum.Operation.Call,
            0,
            0,
            0,
            zeroAddress,
            payableZeroAddress,
            getExecutorSignature(owner)
        );

        // Checking if the delegate allowance is set.
        (bool oneTimeAllowance, uint248 timestamp) = guardrail.delegatedAllowance(address(safe), randomAddresses[0]);
        assertTrue(oneTimeAllowance);
        assertEq(timestamp, uint248(block.timestamp));
    }

    // Test function to check revert if the guard is set and immediate setting of delegates is initiated
    function testImmediateDelegateAllowanceRevert() public {
        // Setting up the guard.
        setupGuard();

        // Create a random address for the delegate.
        createRandomAddresses(1);

        // Expect revert as the guard is set.
        vm.expectRevert(Guardrail.GuardAlreadySet.selector);
        vm.prank(owner);
        bytes memory immediateDelegateAllowanceData =
            abi.encodeWithSelector(guardrail.immediateDelegateAllowance.selector, randomAddresses[0], true);
        safe.execTransaction(
            address(guardrail),
            0,
            immediateDelegateAllowanceData,
            Enum.Operation.Call,
            0,
            0,
            0,
            zeroAddress,
            payableZeroAddress,
            getExecutorSignature(owner)
        );
    }

    // Test function to check if delegates can be set after guardrail is added as a guard
    function testDelegateAllowanceAfterGuardSetup() public {
        // Setting up the guard.
        setupGuard();

        // Create a random address for the delegate.
        createRandomAddresses(1);

        // Setting the delegate allowance.
        vm.prank(owner);
        bytes memory delegateAllowanceData =
            abi.encodeWithSelector(guardrail.delegateAllowance.selector, randomAddresses[0], true, false);
        safe.execTransaction(
            address(guardrail),
            0,
            delegateAllowanceData,
            Enum.Operation.Call,
            0,
            0,
            0,
            zeroAddress,
            payableZeroAddress,
            getExecutorSignature(owner)
        );

        // Checking if the delegate allowance is set.
        (bool oneTimeAllowance, uint248 timestamp) = guardrail.delegatedAllowance(address(safe), randomAddresses[0]);
        assertTrue(oneTimeAllowance);
        assertEq(timestamp, uint248(DELAY + block.timestamp));
    }

    // Test function to check revert if delegate is not set
    function testDelegateAllowanceRevert() public {
        // Setting up the guard.
        setupGuard();

        // Create a random address for the delegate.
        createRandomAddresses(1);

        // Expect revert as the delegate allowance is not set.
        vm.expectRevert(abi.encodeWithSelector(Guardrail.DelegateCallNotAllowed.selector, randomAddresses[0]));
        vm.prank(owner);
        safe.execTransaction(
            randomAddresses[0], // Sending a DelegateCall to a random address
            0, // Value to be sent
            emptyBytes,
            Enum.Operation.DelegateCall,
            0,
            0,
            0,
            zeroAddress,
            payableZeroAddress,
            getExecutorSignature(owner)
        );
    }

    // Test function to check if delegate schedule timestamp is not passed
    function testDelegateAllowanceTimestampNotPassed() public {
        // Setting up the guard.
        setupGuard();

        // Create a random address for the delegate.
        createRandomAddresses(1);

        // Setting the delegate allowance with a future timestamp.
        vm.prank(owner);
        bytes memory delegateAllowanceData =
            abi.encodeWithSelector(guardrail.delegateAllowance.selector, randomAddresses[0], true, false);
        safe.execTransaction(
            address(guardrail),
            0,
            delegateAllowanceData,
            Enum.Operation.Call,
            0,
            0,
            0,
            zeroAddress,
            payableZeroAddress,
            getExecutorSignature(owner)
        );

        // Expect revert as the delegate allowance timestamp is not passed yet.
        vm.expectRevert(abi.encodeWithSelector(Guardrail.DelegateCallNotAllowed.selector, randomAddresses[0]));
        vm.prank(owner);
        safe.execTransaction(
            randomAddresses[0], // Sending a DelegateCall to a random address
            0, // Value to be sent
            emptyBytes,
            Enum.Operation.DelegateCall,
            0,
            0,
            0,
            zeroAddress,
            payableZeroAddress,
            getExecutorSignature(owner)
        );
    }

    // Test function to check if added delegates can be removed
    function testDelegateRemoval() public {
        // Setting up the guard.
        setupGuard();

        // Create a random address for the delegate.
        createRandomAddresses(1);

        // Setting the delegate allowance.
        vm.prank(owner);
        bytes memory delegateAllowanceData =
            abi.encodeWithSelector(guardrail.delegateAllowance.selector, randomAddresses[0], true, false);
        safe.execTransaction(
            address(guardrail),
            0,
            delegateAllowanceData,
            Enum.Operation.Call,
            0,
            0,
            0,
            zeroAddress,
            payableZeroAddress,
            getExecutorSignature(owner)
        );

        // Checking if the delegate allowance is set.
        (bool oneTimeAllowance, uint248 timestamp) = guardrail.delegatedAllowance(address(safe), randomAddresses[0]);
        assertTrue(oneTimeAllowance);
        assertEq(timestamp, uint248(DELAY + block.timestamp));

        // Removing the delegate allowance.
        vm.prank(owner);
        bytes memory removeDelegateData =
            abi.encodeWithSelector(guardrail.delegateAllowance.selector, randomAddresses[0], false, true);
        safe.execTransaction(
            address(guardrail),
            0,
            removeDelegateData,
            Enum.Operation.Call,
            0,
            0,
            0,
            zeroAddress,
            payableZeroAddress,
            getExecutorSignature(owner)
        );

        // Checking if the delegate allowance is removed.
        (oneTimeAllowance, timestamp) = guardrail.delegatedAllowance(address(safe), randomAddresses[0]);
        assertFalse(oneTimeAllowance);
        assertEq(timestamp, uint248(0));
    }

    // Test function to check the event emitted on delegate update (adding and removing)
    function testDelegateAllowanceEvent() public {
        // Setting up the guard.
        setupGuard();

        // Create a random address for the delegate.
        createRandomAddresses(1);

        // Expect event on delegate allowance update.
        vm.expectEmit(true, true, false, true, address(guardrail));
        emit Guardrail.DelegateAllowanceUpdated(address(safe), randomAddresses[0], true, DELAY + block.timestamp);

        // Setting the delegate allowance.
        vm.prank(owner);
        bytes memory delegateAllowanceData =
            abi.encodeWithSelector(guardrail.delegateAllowance.selector, randomAddresses[0], true, false);
        safe.execTransaction(
            address(guardrail),
            0,
            delegateAllowanceData,
            Enum.Operation.Call,
            0,
            0,
            0,
            zeroAddress,
            payableZeroAddress,
            getExecutorSignature(owner)
        );
    }

    // Test function to check if delegates can do delegate calls
    function testDelegateCallByAllowedDelegate() public {
        // Setting up the guard.
        setupGuard();

        // Create a random address for the delegate.
        createRandomAddresses(1);

        // Setting the delegate allowance.
        vm.prank(owner);
        bytes memory delegateAllowanceData =
            abi.encodeWithSelector(guardrail.delegateAllowance.selector, randomAddresses[0], true, false);
        safe.execTransaction(
            address(guardrail),
            0,
            delegateAllowanceData,
            Enum.Operation.Call,
            0,
            0,
            0,
            zeroAddress,
            payableZeroAddress,
            getExecutorSignature(owner)
        );

        // Increasing the timestamp to pass the delegate allowance delay.
        vm.warp(block.timestamp + DELAY + 1);

        // Now the delegate call should succeed.
        vm.prank(owner);
        safe.execTransaction(
            randomAddresses[0], // Sending a DelegateCall to a random address
            0, // Value to be sent
            emptyBytes,
            Enum.Operation.DelegateCall,
            0,
            0,
            0,
            zeroAddress,
            payableZeroAddress,
            getExecutorSignature(owner)
        );
    }

    // Test function to check if delegates can do delegate calls through modules
    function testDelegateCallThroughModule() public {
        // Setting up the guard.
        setupGuard();

        // Create a random address for the delegate.
        createRandomAddresses(1);

        // Setting the delegate allowance.
        vm.prank(owner);
        bytes memory delegateAllowanceData =
            abi.encodeWithSelector(guardrail.delegateAllowance.selector, randomAddresses[0], true, false);
        safe.execTransaction(
            address(guardrail),
            0,
            delegateAllowanceData,
            Enum.Operation.Call,
            0,
            0,
            0,
            zeroAddress,
            payableZeroAddress,
            getExecutorSignature(owner)
        );

        // Increasing the timestamp to pass the delegate allowance delay.
        vm.warp(block.timestamp + DELAY + 1);

        // Set the module in the Safe contract.
        MockModule mockModule = new MockModule();
        bytes memory setModuleData = abi.encodeWithSelector(safe.enableModule.selector, address(mockModule));
        vm.prank(owner);
        safe.execTransaction(
            address(safe),
            0,
            setModuleData,
            Enum.Operation.Call,
            0,
            0,
            0,
            zeroAddress,
            payableZeroAddress,
            getExecutorSignature(owner)
        );

        // Now the delegate call should succeed through a module.
        mockModule.execTransaction(
            address(safe), // Safe address
            randomAddresses[0], // Delegate address
            0, // Value to be sent
            emptyBytes, // Data
            Enum.Operation.DelegateCall // Operation type
        );
    }

    // Test function to check if delegate call is not allowed if the delegate allowance is not set.
    function testDelegateCallNotAllowedThroughModule() public {
        // Setting up the guard.
        setupGuard();

        // Set the module in the Safe contract.
        MockModule mockModule = new MockModule();
        bytes memory setModuleData = abi.encodeWithSelector(safe.enableModule.selector, address(mockModule));
        vm.prank(owner);
        safe.execTransaction(
            address(safe),
            0,
            setModuleData,
            Enum.Operation.Call,
            0,
            0,
            0,
            zeroAddress,
            payableZeroAddress,
            getExecutorSignature(owner)
        );

        // Create a random address for the delegate.
        createRandomAddresses(1);

        // Expect revert as the delegate allowance is not set.
        vm.expectRevert(abi.encodeWithSelector(Guardrail.DelegateCallNotAllowed.selector, randomAddresses[0]));
        mockModule.execTransaction(
            address(safe), // Safe address
            randomAddresses[0], // Delegate address
            0, // Value to be sent
            emptyBytes, // Data
            Enum.Operation.DelegateCall // Operation type
        );
    }
}
