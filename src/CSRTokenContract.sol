pragma solidity ^0.8.16;

import "./turnstile.sol";
import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/access/Ownable.sol";

contract CSRTokenContract is ERC20, Ownable {
    address turnstile;

    constructor(string memory _name, string memory _symbol, address _turnstile)
      ERC20(_name, _symbol){
        turnstile = _turnstile;
        _mint(msg.sender, 1000);
    }

    function mint(address _receiver, uint256 amount) public onlyOwner{
        _mint(_receiver, amount);
    }

    function register(address to) public{
        Turnstile(turnstile).register(to);
    }

    function assign(uint256 id) public{
        Turnstile(turnstile).assign(id);
    }
}
