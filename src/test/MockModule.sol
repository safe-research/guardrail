// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity =0.8.28;

import {Enum} from "safe-smart-account/contracts/libraries/Enum.sol";
import {ISafe} from "safe-smart-account/contracts/interfaces/ISafe.sol";

contract MockModule {
    function execTransaction(address safe, address to, uint256 value, bytes calldata data, Enum.Operation operation)
        external
        payable
    {
        require(ISafe(safe).execTransactionFromModule(to, value, data, operation), "tx failed");
    }
}
