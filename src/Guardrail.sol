// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity =0.8.28;

import {ITransactionGuard, IERC165, GuardManager} from "safe-smart-account/contracts/base/GuardManager.sol";
import {IModuleGuard} from "safe-smart-account/contracts/base/ModuleManager.sol";
import {Enum} from "safe-smart-account/contracts/libraries/Enum.sol";
import {SafeInterface} from "./interfaces/SafeInterface.sol";

contract Guardrail is ITransactionGuard, IModuleGuard {
    /**
     * @notice The allowance struct to store the status of the delegate
     * @param oneTimeAllowance The status of the one time allowance
     * @param allowedTimestamp The timestamp from when the delegate is allowed
     * @dev The one time allowance is used to allow the delegate to execute a transaction only once
     */
    struct Allowance {
        bool oneTimeAllowance;
        uint248 allowedTimestamp;
    }

    /**
     * @notice The storage slot for the guard
     * @dev This is used to check if the guard is set
     *      Value = `keccak256("guard_manager.guard.address")`
     */
    bytes32 public constant GUARD_STORAGE_SLOT = 0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8;

    /**
     * @notice The delay for the guard removal and delegate allowance
     */
    uint256 public immutable DELAY;

    /**
     * @notice The schedule for the guard removal
     * @dev safe The address of the safe
     *      timestamp The timestamp of the schedule
     */
    mapping(address safe => uint256 timestamp) public removalSchedule;

    /**
     * @notice The delegated allowance info
     * @dev safe The address of the safe
     *      to The address of the delegate
     *      allowance The delegated allowance
     */
    mapping(address safe => mapping(address to => Allowance allowance)) public delegatedAllowance;

    /**
     * @notice Event emitted when the guard removal is scheduled
     * @param safe The address of the safe
     * @param timestamp The timestamp of the schedule
     */
    event GuardRemovalScheduled(address indexed safe, uint256 timestamp);

    /**
     * @notice Event emitted when the delegate allowance is updated
     * @param safe The address of the safe
     * @param to The address of the delegate
     * @param oneTimeAllowance The status of the one time allowance
     * @param timestamp The timestamp at which the delegate is allowed
     */
    event DelegateAllowanceUpdated(address indexed safe, address indexed to, bool oneTimeAllowance, uint256 timestamp);

    /**
     * @notice Error indicating invalid timestamp
     * @dev The timestamp is invalid if it is in the future or zero
     */
    error InvalidTimestamp();

    /**
     * @notice Error indicating that the guard is already set
     */
    error GuardAlreadySet();

    /**
     * @notice Error indicating that the operation DelegateCall is not allowed
     * @param to The address of the delegate to which the operation is not allowed
     */
    error DelegateCallNotAllowed(address to);

    /**
     * @notice Error indicating that the selector is invalid
     */
    error InvalidSelector();

    /**
     * @param delay The delay for the guard removal and delegate allowance
     */
    constructor(uint256 delay) {
        DELAY = delay;
    }

    /**
     * @notice Function to schedule the guard removal
     */
    function scheduleGuardRemoval() public {
        removalSchedule[msg.sender] = DELAY + block.timestamp;

        emit GuardRemovalScheduled(msg.sender, DELAY + block.timestamp);
    }

    /**
     * @notice Internal function to check if the guard removal is scheduled
     * @param safe The address of the safe
     */
    function _removeGuard(address safe) internal {
        uint256 removalTimestamp = removalSchedule[safe];
        require(removalTimestamp > 0 && removalTimestamp < block.timestamp, InvalidTimestamp());

        removalSchedule[msg.sender] = 0;
    }

    /**
     * @notice Function to set the delegate allowance immediately
     * @param to The address of the delegate
     * @param oneTime The status of the one time allowance
     * @dev This can be used to set the delegate allowance immediately if the guard is not set
     */
    function immediateDelegateAllowance(address to, bool oneTime) public {
        require(
            abi.decode(SafeInterface(msg.sender).getStorageAt(uint256(GUARD_STORAGE_SLOT), 1), (address)) == address(0),
            GuardAlreadySet()
        );

        _delegateAllowance(msg.sender, to, oneTime, block.timestamp);
    }

    /**
     * @notice Internal function to set the delegate allowance
     * @param safe The address of the safe
     * @param to The address of the delegate
     * @param timestamp The timestamp at which the delegate is allowed
     * @param oneTimeAllowance The status of the one time allowance
     * @dev This will emit the DelegateAllowanceUpdated event
     */
    function _delegateAllowance(address safe, address to, bool oneTimeAllowance, uint256 timestamp) internal {
        delegatedAllowance[safe][to] = Allowance(oneTimeAllowance, uint248(timestamp));

        emit DelegateAllowanceUpdated(safe, to, oneTimeAllowance, timestamp);
    }

    /**
     * @notice Function to update the delegate allowance
     * @param safe The address of the safe
     * @param to The address of the delegate
     * @param oneTimeAllowance The status of the one time allowance
     * @param reset true if the delegate allowance should be reset
     * @dev This will fail if the delegate allowance is not scheduled
     */
    function delegateAllowance(address safe, address to, bool oneTimeAllowance, bool reset) public {
        _delegateAllowance(safe, to, oneTimeAllowance, reset ? 0 : DELAY + block.timestamp);
    }

    /**
     * @notice Function to decode the selector from the data
     * @param data The data to decode
     * @return selector The decoded selector
     */
    function _decodeSelector(bytes calldata data) internal pure returns (bytes4 selector) {
        if (data.length >= 4) {
            return bytes4(data);
        } else if (data.length == 0) {
            return bytes4(0);
        } else {
            revert InvalidSelector();
        }
    }

    /**
     * @notice Function to check if the delegate is allowed if the operation is delegate call
     * @param safe The address of the safe
     * @param to The address of the delegate
     * @param operation The operation to check
     * @dev This will revert if the operation is delegate call, but the {to} is not a allowed delegate. This will also
     *      remove the delegate allowance if the one time allowance is set
     */
    function _checkOperationAndAllowance(address safe, address to, Enum.Operation operation) internal {
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

    /**
     * @inheritdoc ITransactionGuard
     * @dev This is not a view function because of one time delegate transactions and guard removal updates
     */
    function checkTransaction(
        address to,
        uint256,
        bytes calldata data,
        Enum.Operation operation,
        uint256,
        uint256,
        uint256,
        address,
        address payable,
        bytes calldata,
        address
    ) external override {
        bytes4 selector = _decodeSelector(data);
        if (to == msg.sender && selector == GuardManager.setGuard.selector) {
            _removeGuard(msg.sender);
        }

        _checkOperationAndAllowance(msg.sender, to, operation);
    }

    /**
     * @inheritdoc ITransactionGuard
     */
    function checkAfterExecution(bytes32 hash, bool success) external {}

    /**
     * @inheritdoc IModuleGuard
     */
    function checkModuleTransaction(address to, uint256, bytes calldata, Enum.Operation operation, address)
        external
        override
        returns (bytes32)
    {
        _checkOperationAndAllowance(msg.sender, to, operation);

        return bytes32(0);
    }

    /**
     * @inheritdoc IModuleGuard
     */
    function checkAfterModuleExecution(bytes32 txHash, bool success) external {}

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId) external pure returns (bool supported) {
        supported = interfaceId == type(IERC165).interfaceId || interfaceId == type(IModuleGuard).interfaceId
            || interfaceId == type(ITransactionGuard).interfaceId;
    }
}
