pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "../src/Turnstile.sol";

contract ReceiveSmartContract {
    receive() external payable {}
}

contract TurnstileTest is Test {
    Turnstile public turnstile;

    address public cosmosModule = address(10000001);
    address payable public paymentRecipient = payable(address(10000002));

    address public receiveContract = address(new ReceiveSmartContract());
    bytes public code = receiveContract.code;

    event Register(address smartContract, address recipient, uint256 tokenId);
    event Assign(address smartContract, uint256 tokenId);
    event Withdraw(uint256 tokenId, address recipient, uint256 feeAmount);
    event DistributeFees(uint256 tokenId, uint256 feeAmount, address smartContract, uint256 balanceUpdatedBlock);

    function setUp() public {
        vm.prank(cosmosModule);
        turnstile = new Turnstile();
    }

    function _testGetters() public {
        assertEq(turnstile.currentCounterId(), 0);
        address recipient = address(uint160(1));

        for (uint256 i = 1; i < 50; i++) {
            address smartContract = address(uint160(i*200));
            address smartContract2 = address(uint160(i*200000));
            vm.etch(smartContract, code);
            vm.etch(smartContract2, code);

            vm.prank(smartContract);
            uint256 tokenId = turnstile.register(recipient);
            vm.prank(smartContract2);
            uint256 assignedTokenId = turnstile.assign(tokenId);

            assertEq(turnstile.currentCounterId(), i);
            assertEq(turnstile.currentCounterId(), tokenId + 1);
            assertEq(tokenId, assignedTokenId);
            assertEq(turnstile.balanceOf(recipient), i);
            assertEq(turnstile.ownerOf(tokenId), recipient);
            assertEq(turnstile.getTokenId(smartContract), tokenId);
            assertEq(turnstile.getTokenId(smartContract2), tokenId);
            assertEq(turnstile.isRegistered(smartContract), true);
            assertEq(turnstile.isRegistered(smartContract2), true);
        }

        vm.expectRevert(Turnstile.Unregistered.selector);
        turnstile.getTokenId(cosmosModule);
    }

    function testCurrentCounterId() public {
        _testGetters();
    }

    function testGetTokenId() public {
        _testGetters();
    }

    function testIsRegisteredntTokenId() public {
        _testGetters();
    }

    function testRegister(address _smartContract, address _recipient) public {
        vm.assume(_smartContract != address(this) && _smartContract != address(turnstile));
        vm.assume(_smartContract != address(this));
        vm.assume(_recipient != address(0));

        vm.etch(_smartContract, code);
        vm.startPrank(_smartContract);

        vm.expectRevert(Turnstile.InvalidRecipient.selector);
        turnstile.register(address(0));

        uint256 currentCounterId = turnstile.currentCounterId();

        assertEq(currentCounterId, 0);
        assertEq(turnstile.balanceOf(_recipient), 0);

        vm.expectRevert("ERC721: invalid token ID");
        turnstile.ownerOf(currentCounterId);

        vm.expectEmit(true, true, true, true);
        emit Register(_smartContract, _recipient, currentCounterId);
        uint256 tokenId = turnstile.register(_recipient);

        assertEq(tokenId, currentCounterId);
        assertEq(turnstile.currentCounterId(), tokenId + 1);
        assertEq(turnstile.balanceOf(_recipient), 1);
        assertEq(turnstile.ownerOf(tokenId), _recipient);
        assertEq(turnstile.getTokenId(_smartContract), tokenId);
        assertEq(turnstile.isRegistered(_smartContract), true);

        vm.expectRevert(Turnstile.AlreadyRegistered.selector);
        turnstile.register(_recipient);

        vm.expectRevert(Turnstile.AlreadyRegistered.selector);
        turnstile.assign(currentCounterId);

        vm.stopPrank();

        vm.expectRevert(Turnstile.InvalidTokenId.selector);
        turnstile.assign(currentCounterId + 1);
    }

    function testAssign(address _smartContract, address _recipient) public {
        vm.assume(_smartContract != address(this) && _smartContract != receiveContract && _smartContract != address(turnstile));
        vm.assume(_recipient != address(0));

        vm.prank(receiveContract);
        uint256 tokenId = turnstile.register(_recipient);
        assertEq(turnstile.getTokenId(receiveContract), tokenId);
        assertEq(turnstile.isRegistered(receiveContract), true);

        vm.prank(receiveContract);
        vm.expectRevert(Turnstile.AlreadyRegistered.selector);
        turnstile.assign(tokenId);

        vm.etch(_smartContract, code);
        vm.startPrank(_smartContract);

        vm.expectRevert(Turnstile.InvalidTokenId.selector);
        turnstile.assign(99);

        vm.expectEmit(true, true, true, true);
        emit Assign(_smartContract, tokenId);
        uint256 assignedTokenId = turnstile.assign(tokenId);

        assertEq(tokenId, assignedTokenId);
        assertEq(turnstile.currentCounterId(), 1);
        assertEq(turnstile.balanceOf(_recipient), 1);
        assertEq(turnstile.ownerOf(tokenId), _recipient);
        assertEq(turnstile.getTokenId(_smartContract), tokenId);
        assertEq(turnstile.isRegistered(_smartContract), true);

        vm.stopPrank();
    }

    function testDistributeFees(address _recipient, uint256 _amount, address _sender) public {
        vm.assume(_recipient != address(0));
        vm.assume(_sender != cosmosModule && _sender != address(turnstile));
        vm.assume(_amount > 0 && _amount < 1000 ether);
        vm.deal(_sender, 1000 ether);
        vm.deal(cosmosModule, 10000 ether);

        assertEq(turnstile.owner(), cosmosModule);
        assertEq(address(turnstile).balance, 0);

        vm.prank(receiveContract);
        uint256 tokenId = turnstile.register(_recipient);
        assertEq(turnstile.getTokenId(receiveContract), tokenId);
        assertEq(turnstile.isRegistered(receiveContract), true);

        vm.prank(_sender);
        vm.expectRevert("Ownable: caller is not the owner");
        turnstile.distributeFees{value: _amount}(tokenId, receiveContract, block.number);

        vm.startPrank(cosmosModule);

        vm.expectRevert(Turnstile.NothingToDistribute.selector);
        turnstile.distributeFees{value: 0}(tokenId, receiveContract, block.number);

        assertEq(turnstile.balances(tokenId), 0);

        vm.roll(10);
        vm.expectRevert(Turnstile.InvalidBlockNumber.selector);
        turnstile.distributeFees{value: _amount}(tokenId, receiveContract, block.number + 100);

        vm.expectEmit(true, true, true, true);
        emit DistributeFees(tokenId, _amount, receiveContract, block.number);
        turnstile.distributeFees{value: _amount}(tokenId, receiveContract, block.number);

        assertEq(turnstile.balances(tokenId), _amount);
        assertEq(address(turnstile).balance, _amount);

        vm.expectRevert(Turnstile.BalanceUpdatedBlockOverlap.selector);
        turnstile.distributeFees{value: _amount}(tokenId, receiveContract, block.number - 1);

        vm.roll(20);

        vm.expectEmit(true, true, true, true);
        emit DistributeFees(tokenId, _amount, receiveContract, block.number);
        turnstile.distributeFees{value: _amount}(tokenId, receiveContract, block.number);

        assertEq(turnstile.balances(tokenId), _amount * 2);
        assertEq(address(turnstile).balance, _amount * 2);

        vm.stopPrank();
    }

    function testWithdraw(
        address _recipient,
        address _hacker,
        uint256 _rewardAmount,
        uint256 _withdrawAmount
    ) public {
        vm.assume(_recipient != address(0) && _recipient != address(this) && _recipient != _hacker);
        vm.assume(_rewardAmount > 0 && _rewardAmount < 1000 ether);
        vm.assume(_withdrawAmount > 0 && _withdrawAmount < 1000 ether);
        vm.deal(cosmosModule, 1000 ether);

        vm.prank(receiveContract);
        uint256 tokenId = turnstile.register(_recipient);
        assertEq(turnstile.getTokenId(receiveContract), tokenId);
        assertEq(turnstile.isRegistered(receiveContract), true);

        assertEq(turnstile.balances(tokenId), 0);
        assertEq(address(turnstile).balance, 0);
        vm.prank(_recipient);
        vm.expectRevert(Turnstile.NothingToWithdraw.selector);
        turnstile.withdraw(tokenId, paymentRecipient, _rewardAmount);

        vm.prank(cosmosModule);
        vm.roll(10);
        turnstile.distributeFees{value: _rewardAmount}(tokenId, receiveContract, block.number);

        assertEq(turnstile.balances(tokenId), _rewardAmount);
        assertEq(address(turnstile).balance, _rewardAmount);

        vm.prank(_hacker);
        vm.expectRevert(Turnstile.NotAnOwner.selector);
        turnstile.withdraw(tokenId, payable(_hacker), _withdrawAmount);

        vm.startPrank(_recipient);

        vm.expectRevert("ERC721: invalid token ID");
        turnstile.withdraw(99, paymentRecipient, _withdrawAmount);

        vm.expectRevert(Turnstile.NothingToWithdraw.selector);
        turnstile.withdraw(tokenId, paymentRecipient, 0);

        assertEq(turnstile.balances(tokenId), _rewardAmount);
        assertEq(address(turnstile).balance, _rewardAmount);

        uint256 actualWithdrawAmount = _withdrawAmount >= _rewardAmount ? _rewardAmount : _withdrawAmount;
        vm.expectEmit(true, true, true, true);
        emit Withdraw(tokenId, paymentRecipient, actualWithdrawAmount);
        uint256 amountPaid = turnstile.withdraw(tokenId, paymentRecipient, _withdrawAmount);

        assertEq(amountPaid, actualWithdrawAmount);
        assertEq(address(paymentRecipient).balance, actualWithdrawAmount);
        assertEq(turnstile.balances(tokenId), _rewardAmount - actualWithdrawAmount);
        assertEq(address(turnstile).balance, _rewardAmount - actualWithdrawAmount);

        vm.stopPrank();
    }

    function testWithdrawWithNftTransfer(
        address _recipient,
        address _hacker,
        uint256 _rewardAmount,
        uint256 _withdrawAmount
    ) public {
        vm.assume(_recipient != address(0) && _recipient != address(this) && _recipient != _hacker && _recipient != receiveContract);
        vm.assume(_rewardAmount > 0 && _rewardAmount < 1000 ether);
        vm.assume(_withdrawAmount > 0 && _withdrawAmount < 1000 ether);
        vm.deal(cosmosModule, 1000 ether);

        vm.prank(receiveContract);
        uint256 tokenId = turnstile.register(_recipient);
        assertEq(turnstile.getTokenId(receiveContract), tokenId);
        assertEq(turnstile.isRegistered(receiveContract), true);

        assertEq(turnstile.balances(tokenId), 0);
        assertEq(address(turnstile).balance, 0);
        vm.prank(_recipient);
        vm.expectRevert(Turnstile.NothingToWithdraw.selector);
        turnstile.withdraw(tokenId, paymentRecipient, _rewardAmount);

        vm.prank(cosmosModule);
        vm.roll(10);
        turnstile.distributeFees{value: _rewardAmount}(tokenId, receiveContract, block.number);

        assertEq(turnstile.balances(tokenId), _rewardAmount);
        assertEq(address(turnstile).balance, _rewardAmount);

        vm.prank(_hacker);
        vm.expectRevert(Turnstile.NotAnOwner.selector);
        turnstile.withdraw(tokenId, payable(_hacker), _rewardAmount);

        vm.prank(_recipient);
        turnstile.transferFrom(_recipient, receiveContract, tokenId);

        vm.startPrank(_recipient);

        vm.expectRevert("ERC721: invalid token ID");
        turnstile.withdraw(99, paymentRecipient, _withdrawAmount);

        vm.expectRevert(Turnstile.NotAnOwner.selector);
        turnstile.withdraw(tokenId, paymentRecipient, 0);

        assertEq(turnstile.balances(tokenId), _rewardAmount);
        assertEq(address(turnstile).balance, _rewardAmount);

        vm.expectRevert(Turnstile.NotAnOwner.selector);
        turnstile.withdraw(tokenId, paymentRecipient, _withdrawAmount);

        assertEq(turnstile.balances(tokenId), _rewardAmount);
        assertEq(address(turnstile).balance, _rewardAmount);

        vm.stopPrank();

        vm.startPrank(receiveContract);

        uint256 actualWithdrawAmount = _withdrawAmount >= _rewardAmount ? _rewardAmount : _withdrawAmount;
        vm.expectEmit(true, true, true, true);
        emit Withdraw(tokenId, receiveContract, actualWithdrawAmount);
        uint256 amountPaid = turnstile.withdraw(tokenId, payable(receiveContract), _withdrawAmount);

        assertEq(amountPaid, actualWithdrawAmount);
        assertEq(address(receiveContract).balance, actualWithdrawAmount);
        assertEq(turnstile.balances(tokenId), _rewardAmount - actualWithdrawAmount);
        assertEq(address(turnstile).balance, _rewardAmount - actualWithdrawAmount);

        vm.stopPrank();
    }
}
