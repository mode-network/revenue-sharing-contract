pragma solidity 0.8.17;

import "forge-std/Script.sol";
import "../src/SFSTokenContract.sol";

contract SFSTokenContractScript is Script {
    function setUp() public {}

    function run() external {

        vm.broadcast();
        new SFSTokenContract("SFS Token", "SFSTOK", address(bytes20(bytes("0x2a0a18fe492d4dc4d0a3db55bd01cbcc938b2b02"))));
    }
}
