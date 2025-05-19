// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity =0.8.28;

import {ITransactionGuard, IERC165, GuardManager} from "safe-smart-account/contracts/base/GuardManager.sol";
import {IModuleGuard} from "safe-smart-account/contracts/base/ModuleManager.sol";
import {Enum} from "safe-smart-account/contracts/libraries/Enum.sol";

contract Guardrail is ITransactionGuard, IModuleGuard {
    /**
     * @notice The allowance struct to store the status of the delegate
     * @param allowed The status of the delegate
     * @param oneTimeAllowance The status of the one time allowance
     * @dev The one time allowance is used to allow the delegate to execute a transaction only once
     */
    struct Allowance {
        bool allowed;
        bool oneTimeAllowance;
    }

    /**
     * @notice The allowance schedule struct to store the timestamp and one time allowance status
     * @param timestamp The timestamp of the schedule
     * @param oneTimeAllowance The status of the one time allowance
     * @dev The one time allowance is used to allow the delegate to execute a transaction only once
     */
    struct AllowanceSchedule {
        uint256 timestamp;
        bool oneTimeAllowance;
    }

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
     * @notice The schedule for the delegated allowance update
     * @dev safe The address of the safe
     *      to The address of the delegate
     *      allowanceSchedule The schedule for the delegated allowance
     */
    mapping(address safe => mapping(address to => AllowanceSchedule allowanceSchedule)) public delegatedUpdateSchedule;

    /**
     * @notice Event emitted when the guard removal is scheduled
     * @param safe The address of the safe
     * @param timestamp The timestamp of the schedule
     */
    event GuardRemovalScheduled(address indexed safe, uint256 timestamp);

    /**
     * @notice Event emitted when the delegate allowance is scheduled
     * @param safe The address of the safe
     * @param to The address of the delegate
     * @param timestamp The timestamp of the schedule
     */
    event DelegateAllowanceScheduled(address indexed safe, address indexed to, uint256 timestamp);

    /**
     * @notice Event emitted when the delegate allowance is updated
     * @param safe The address of the safe
     * @param to The address of the delegate
     * @param newAllowance The status of the new allowance
     * @param oneTimeAllowance The status of the one time allowance
     */
    event DelegateAllowanceUpdated(address indexed safe, address indexed to, bool newAllowance, bool oneTimeAllowance);

    /**
     * @notice Error indicating invalid timestamp
     * @dev The timestamp is invalid if it is in the future or zero
     */
    error InvalidTimestamp();

    /**
     * @notice Error indicating that the operation DelegateCall is not allowed
     */
    error DelegateCallNotAllowed();

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
     * @notice Function to schedule the delegate allowance
     * @param to The address of the delegate
     * @param oneTime The status of the one time allowance
     * @dev The one time allowance is used to allow the delegate to execute a transaction only once
     */
    function scheduleDelegateAllowance(address to, bool oneTime) public {
        delegatedUpdateSchedule[msg.sender][to] = AllowanceSchedule(DELAY + block.timestamp, oneTime);

        emit DelegateAllowanceScheduled(msg.sender, to, DELAY + block.timestamp);
    }

    /**
     * @notice Function to update the delegate allowance
     * @param safe The address of the safe
     * @param to The address of the delegate
     * @dev This will fail if the delegate allowance is not scheduled
     */
    function delegateAllowance(address safe, address to) public {
        AllowanceSchedule memory allowanceSchedule = delegatedUpdateSchedule[safe][to];
        require(allowanceSchedule.timestamp > 0 && allowanceSchedule.timestamp < block.timestamp, InvalidTimestamp());

        bool oldAllowance = delegatedAllowance[safe][to].allowed;
        delegatedAllowance[safe][to] = Allowance(!oldAllowance, allowanceSchedule.oneTimeAllowance);
        delete delegatedUpdateSchedule[safe][to];

        emit DelegateAllowanceUpdated(safe, to, !oldAllowance, allowanceSchedule.oneTimeAllowance);
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
     * @notice Function to check if the delegate is allowed
     * @param safe The address of the safe
     * @param to The address of the delegate
     * @return allowed The status of the delegate
     * @dev This will return true if the delegate is allowed and false if the delegate is not allowed. This will also
     *      remove the delegate allowance if the one time allowance is set
     */
    function _checkAllowedDelegate(address safe, address to) internal returns (bool allowed) {
        Allowance memory allowance = delegatedAllowance[safe][to];
        if (allowance.allowed) {
            if (allowance.oneTimeAllowance) {
                delete delegatedAllowance[safe][to];
            }
            allowed = true;
        }
    }

    /**
     * @notice Internal function to check if the operation is DelegateCall
     * @param operation The operation to check
     * @dev This will revert if the operation is DelegateCall
     */
    function _delegateCallNotAllowed(Enum.Operation operation) internal pure {
        require(operation != Enum.Operation.DelegateCall, DelegateCallNotAllowed());
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

        if (_checkAllowedDelegate(msg.sender, to)) {
            return;
        }

        _delegateCallNotAllowed(operation);
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
        if (_checkAllowedDelegate(msg.sender, to)) {
            return bytes32(0);
        }

        _delegateCallNotAllowed(operation);
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
