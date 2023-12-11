// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./FeeSharing.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract SFSTokenContract is ERC20, Ownable {
    address feeshare;
    constructor(
        string memory _name,
        string memory _symbol,
        address _feeshare
    ) ERC20(_name, _symbol) Ownable(msg.sender) {
        feeshare = _feeshare;
        _mint(msg.sender, 1000);
    }

    function mint(address _receiver, uint256 amount) public onlyOwner{
        _mint(_receiver, amount);
    }

    function register(address to) public{
        FeeSharing(feeshare).register(to);
    }

    function assign(uint256 id) public{
        FeeSharing(feeshare).assign(id);
    }
}
