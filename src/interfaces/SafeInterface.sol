// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity =0.8.28;

import {ISafe} from "safe-smart-account/contracts/interfaces/ISafe.sol";

/**
 * @title SafeInterface
 * @dev This interface is used to interact with the Safe contract.
 *      It extends the ISafe interface to include a function for reading storage.
 */
interface SafeInterface is ISafe {
    /**
     * @notice Reads `length` bytes of storage in the current contract
     * @param offset - the offset in the current contract's storage in words to start reading from
     * @param length - the number of words (32 bytes) of data to read
     * @return the bytes that were read.
     */
    function getStorageAt(uint256 offset, uint256 length) external view returns (bytes memory);
}
