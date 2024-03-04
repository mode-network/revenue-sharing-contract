// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";

import {FeeDistributor} from "src/FeeDistributor.sol";
import {FeeSharing} from "src/FeeSharing.sol";

contract FeeDistributorTest is Test {
    FeeDistributor distributor;
    FeeSharing feeSharing;

    function setUp() public {
        feeSharing = new FeeSharing();
        distributor = new FeeDistributor(address(this), address(feeSharing));
    }
}
