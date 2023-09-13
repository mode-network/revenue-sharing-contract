pragma solidity 0.8.17;

import "forge-std/Script.sol";
import "../src/FeeSharing.sol";

contract FeeSharingScript is Script {
    function setUp() public {}

    function run() external {

        vm.broadcast();
        new FeeSharing();
    }
}
