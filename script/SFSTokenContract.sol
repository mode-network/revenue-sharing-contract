pragma solidity 0.8.17;

import "forge-std/Script.sol";
import "../src/SFSTokenContract.sol";

contract SFSTokenContractScript is Script {
    function setUp() public {}

    function run() external {

        vm.broadcast();
        new SFSTokenContract("SFS Token", "SFSTOK", address(bytes20(bytes("0xBBd707815a7F7eb6897C7686274AFabd7B579Ff6"))));
    }
}
