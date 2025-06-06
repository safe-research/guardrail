// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.7.6;
import {Safe} from "safe-smart-account/contracts/Safe.sol";

contract SafeHarness is Safe {
    function getTxGuardAddress() external view returns (address) {
        return getGuard();
    }

    function getModuleGuardAddress() external view returns (address) {
        return getModuleGuard();
    }
}
