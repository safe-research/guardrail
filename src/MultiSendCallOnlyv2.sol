// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity =0.8.28;

import {MultiSendCallOnly} from "safe-smart-account/contracts/libraries/MultiSendCallOnly.sol";

contract MultiSendCallOnlyv2 is MultiSendCallOnly {
    /**
     * @dev Sends multiple transactions and reverts all if one fails. This only allows CALL and with no value.
     * @param transactions Encoded transactions. Each transaction is encoded as a packed bytes of
     *                     to as a address (=> 20 bytes),
     *                     data length as a uint256 (=> 32 bytes),
     *                     data as bytes.
     *                     see abi.encodePacked for more information on packed encoding
     * @notice The code is for the most part the same as the normal MultiSendCallOnly,
     *         but only does CALL and does not pass any value to the CALL.
     * @notice This method is not payable as no value should be passed to the CALL.
     */
    function multiSendNoValue(bytes memory transactions) public {
        /* solhint-disable no-inline-assembly */
        /// @solidity memory-safe-assembly
        assembly {
            let length := mload(transactions)
            let i := 0x20
            for {
                // Pre block is not used in "while mode"
            } lt(i, length) {
                // Post block is not used in "while mode"
            } {
                // First 20 bytes of the data is the address.
                // We shift it right by 96 bits (256 - 160 [20 address bytes]) to right-align the data and zero out unused data.
                let to := shr(0x60, mload(add(transactions, i)))
                // Defaults `to` to `address(this)` if `address(0)` is provided.
                to := or(to, mul(iszero(to), address()))
                // We offset the load address by 20 byte (20 address bytes)
                let dataLength := mload(add(transactions, add(i, 0x14)))
                // We offset the load address by 52 byte (20 address bytes + 32 data length bytes)
                let data := add(transactions, add(i, 0x34))
                let success := call(gas(), to, 0, data, dataLength, 0, 0)
                if iszero(success) {
                    let ptr := mload(0x40)
                    returndatacopy(ptr, 0, returndatasize())
                    revert(ptr, returndatasize())
                }
                // Next entry starts at 52 byte + data length
                i := add(i, add(0x34, dataLength))
            }
        }
        /* solhint-enable no-inline-assembly */
    }
}
