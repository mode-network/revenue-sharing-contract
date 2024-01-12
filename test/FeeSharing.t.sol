pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "../src/FeeSharing.sol";

contract ReceiveSmartContract {
    receive() external payable {}
}

contract FeeSharingTest is Test {
    FeeSharing public feeshare;

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
        feeshare = new FeeSharing();
    }

    function _testGetters() public {
        assertEq(feeshare.currentCounterId(), 0);
        address recipient = address(uint160(1));

        for (uint256 i = 1; i < 50; i++) {
            address smartContract = address(uint160(i*200));
            address smartContract2 = address(uint160(i*200000));
            vm.etch(smartContract, code);
            vm.etch(smartContract2, code);

            vm.prank(smartContract);
            uint256 tokenId = feeshare.register(recipient);
            vm.prank(smartContract2);
            uint256 assignedTokenId = feeshare.assign(tokenId);

            assertEq(feeshare.currentCounterId(), i);
            assertEq(feeshare.currentCounterId(), tokenId + 1);
            assertEq(tokenId, assignedTokenId);
            assertEq(feeshare.balanceOf(recipient), i);
            assertEq(feeshare.ownerOf(tokenId), recipient);
            assertEq(feeshare.getTokenId(smartContract), tokenId);
            assertEq(feeshare.getTokenId(smartContract2), tokenId);
            assertEq(feeshare.isRegistered(smartContract), true);
            assertEq(feeshare.isRegistered(smartContract2), true);
        }

        vm.expectRevert(FeeSharing.Unregistered.selector);
        feeshare.getTokenId(cosmosModule);
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

    function testRegister(uint160 _smartContractI, uint160 _recipientI) public {
        vm.assume(_smartContractI > 10);
        vm.assume(_recipientI > 10);
        address _smartContract = address(_smartContractI);
        address _recipient = address(_recipientI);

        vm.assume(_smartContract != address(this) && _smartContract != address(feeshare));
        vm.assume(_smartContract != address(this));
        vm.assume(_recipient != address(0));

        vm.etch(_smartContract, code);
        vm.startPrank(_smartContract);

        vm.expectRevert(FeeSharing.InvalidRecipient.selector);
        feeshare.register(address(0));

        uint256 currentCounterId = feeshare.currentCounterId();

        assertEq(currentCounterId, 0);
        assertEq(feeshare.balanceOf(_recipient), 0);

        vm.expectRevert("ERC721: invalid token ID");
        feeshare.ownerOf(currentCounterId);

        vm.expectEmit(true, true, true, true);
        emit Register(_smartContract, _recipient, currentCounterId);
        uint256 tokenId = feeshare.register(_recipient);

        assertEq(tokenId, currentCounterId);
        assertEq(feeshare.currentCounterId(), tokenId + 1);
        assertEq(feeshare.balanceOf(_recipient), 1);
        assertEq(feeshare.ownerOf(tokenId), _recipient);
        assertEq(feeshare.getTokenId(_smartContract), tokenId);
        assertEq(feeshare.isRegistered(_smartContract), true);

        vm.expectRevert(FeeSharing.AlreadyRegistered.selector);
        feeshare.register(_recipient);

        vm.expectRevert(FeeSharing.AlreadyRegistered.selector);
        feeshare.assign(currentCounterId);

        vm.stopPrank();

        vm.expectRevert(FeeSharing.InvalidTokenId.selector);
        feeshare.assign(currentCounterId + 1);
    }

    function testAssign(uint160 _smartContractI, uint160 _recipientI) public {
        vm.assume(_smartContractI > 10);
        vm.assume(_recipientI > 10);
        address _smartContract = address(_smartContractI);
        address _recipient = address(_recipientI);

        vm.assume(_smartContract != address(this) && _smartContract != receiveContract && _smartContract != address(feeshare));
        vm.assume(_recipient != address(0));

        vm.prank(receiveContract);
        uint256 tokenId = feeshare.register(_recipient);
        assertEq(feeshare.getTokenId(receiveContract), tokenId);
        assertEq(feeshare.isRegistered(receiveContract), true);

        vm.prank(receiveContract);
        vm.expectRevert(FeeSharing.AlreadyRegistered.selector);
        feeshare.assign(tokenId);

        vm.etch(_smartContract, code);
        vm.startPrank(_smartContract);

        vm.expectRevert(FeeSharing.InvalidTokenId.selector);
        feeshare.assign(99);

        vm.expectEmit(true, true, true, true);
        emit Assign(_smartContract, tokenId);
        uint256 assignedTokenId = feeshare.assign(tokenId);

        assertEq(tokenId, assignedTokenId);
        assertEq(feeshare.currentCounterId(), 1);
        assertEq(feeshare.balanceOf(_recipient), 1);
        assertEq(feeshare.ownerOf(tokenId), _recipient);
        assertEq(feeshare.getTokenId(_smartContract), tokenId);
        assertEq(feeshare.isRegistered(_smartContract), true);

        vm.stopPrank();
    }

    function testDistributeFees(address _recipient, uint256 _amount, address _sender) public {
        vm.assume(_recipient != address(0));
        vm.assume(_sender != cosmosModule && _sender != address(feeshare));
        vm.assume(_amount > 0 && _amount < 1000 ether);
        vm.deal(_sender, 1000 ether);
        vm.deal(cosmosModule, 10000 ether);

        assertEq(feeshare.owner(), cosmosModule);
        assertEq(address(feeshare).balance, 0);

        vm.prank(receiveContract);
        uint256 tokenId = feeshare.register(_recipient);
        assertEq(feeshare.getTokenId(receiveContract), tokenId);
        assertEq(feeshare.isRegistered(receiveContract), true);

        vm.prank(_sender);
        vm.expectRevert("Ownable: caller is not the owner");
        feeshare.distributeFees{value: _amount}(tokenId, receiveContract, block.number);

        vm.startPrank(cosmosModule);

        vm.expectRevert(FeeSharing.NothingToDistribute.selector);
        feeshare.distributeFees{value: 0}(tokenId, receiveContract, block.number);

        assertEq(feeshare.balances(tokenId), 0);

        vm.roll(10);
        vm.expectRevert(FeeSharing.InvalidBlockNumber.selector);
        feeshare.distributeFees{value: _amount}(tokenId, receiveContract, block.number + 100);

        vm.expectEmit(true, true, true, true);
        emit DistributeFees(tokenId, _amount, receiveContract, block.number);
        feeshare.distributeFees{value: _amount}(tokenId, receiveContract, block.number);

        assertEq(feeshare.balances(tokenId), _amount);
        assertEq(address(feeshare).balance, _amount);

        vm.expectRevert(FeeSharing.BalanceUpdatedBlockOverlap.selector);
        feeshare.distributeFees{value: _amount}(tokenId, receiveContract, block.number - 1);

        vm.roll(20);

        vm.expectEmit(true, true, true, true);
        emit DistributeFees(tokenId, _amount, receiveContract, block.number);
        feeshare.distributeFees{value: _amount}(tokenId, receiveContract, block.number);

        assertEq(feeshare.balances(tokenId), _amount * 2);
        assertEq(address(feeshare).balance, _amount * 2);

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
        uint256 tokenId = feeshare.register(_recipient);
        assertEq(feeshare.getTokenId(receiveContract), tokenId);
        assertEq(feeshare.isRegistered(receiveContract), true);

        assertEq(feeshare.balances(tokenId), 0);
        assertEq(address(feeshare).balance, 0);
        vm.prank(_recipient);
        vm.expectRevert(FeeSharing.NothingToWithdraw.selector);
        feeshare.withdraw(tokenId, paymentRecipient, _rewardAmount);

        vm.prank(cosmosModule);
        vm.roll(10);
        feeshare.distributeFees{value: _rewardAmount}(tokenId, receiveContract, block.number);

        assertEq(feeshare.balances(tokenId), _rewardAmount);
        assertEq(address(feeshare).balance, _rewardAmount);

        vm.prank(_hacker);
        vm.expectRevert(FeeSharing.NotAnOwner.selector);
        feeshare.withdraw(tokenId, payable(_hacker), _withdrawAmount);

        vm.startPrank(_recipient);

        vm.expectRevert("ERC721: invalid token ID");
        feeshare.withdraw(99, paymentRecipient, _withdrawAmount);

        vm.expectRevert(FeeSharing.NothingToWithdraw.selector);
        feeshare.withdraw(tokenId, paymentRecipient, 0);

        assertEq(feeshare.balances(tokenId), _rewardAmount);
        assertEq(address(feeshare).balance, _rewardAmount);

        uint256 actualWithdrawAmount = _withdrawAmount >= _rewardAmount ? _rewardAmount : _withdrawAmount;
        vm.expectEmit(true, true, true, true);
        emit Withdraw(tokenId, paymentRecipient, actualWithdrawAmount);
        uint256 amountPaid = feeshare.withdraw(tokenId, paymentRecipient, _withdrawAmount);

        assertEq(amountPaid, actualWithdrawAmount);
        assertEq(address(paymentRecipient).balance, actualWithdrawAmount);
        assertEq(feeshare.balances(tokenId), _rewardAmount - actualWithdrawAmount);
        assertEq(address(feeshare).balance, _rewardAmount - actualWithdrawAmount);

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
        uint256 tokenId = feeshare.register(_recipient);
        assertEq(feeshare.getTokenId(receiveContract), tokenId);
        assertEq(feeshare.isRegistered(receiveContract), true);

        assertEq(feeshare.balances(tokenId), 0);
        assertEq(address(feeshare).balance, 0);
        vm.prank(_recipient);
        vm.expectRevert(FeeSharing.NothingToWithdraw.selector);
        feeshare.withdraw(tokenId, paymentRecipient, _rewardAmount);

        vm.prank(cosmosModule);
        vm.roll(10);
        feeshare.distributeFees{value: _rewardAmount}(tokenId, receiveContract, block.number);

        assertEq(feeshare.balances(tokenId), _rewardAmount);
        assertEq(address(feeshare).balance, _rewardAmount);

        vm.prank(_hacker);
        vm.expectRevert(FeeSharing.NotAnOwner.selector);
        feeshare.withdraw(tokenId, payable(_hacker), _rewardAmount);

        vm.prank(_recipient);
        feeshare.transferFrom(_recipient, receiveContract, tokenId);

        vm.startPrank(_recipient);

        vm.expectRevert("ERC721: invalid token ID");
        feeshare.withdraw(99, paymentRecipient, _withdrawAmount);

        vm.expectRevert(FeeSharing.NotAnOwner.selector);
        feeshare.withdraw(tokenId, paymentRecipient, 0);

        assertEq(feeshare.balances(tokenId), _rewardAmount);
        assertEq(address(feeshare).balance, _rewardAmount);

        vm.expectRevert(FeeSharing.NotAnOwner.selector);
        feeshare.withdraw(tokenId, paymentRecipient, _withdrawAmount);

        assertEq(feeshare.balances(tokenId), _rewardAmount);
        assertEq(address(feeshare).balance, _rewardAmount);

        vm.stopPrank();

        vm.startPrank(receiveContract);

        uint256 actualWithdrawAmount = _withdrawAmount >= _rewardAmount ? _rewardAmount : _withdrawAmount;
        vm.expectEmit(true, true, true, true);
        emit Withdraw(tokenId, receiveContract, actualWithdrawAmount);
        uint256 amountPaid = feeshare.withdraw(tokenId, payable(receiveContract), _withdrawAmount);

        assertEq(amountPaid, actualWithdrawAmount);
        assertEq(address(receiveContract).balance, actualWithdrawAmount);
        assertEq(feeshare.balances(tokenId), _rewardAmount - actualWithdrawAmount);
        assertEq(address(feeshare).balance, _rewardAmount - actualWithdrawAmount);

        vm.stopPrank();
    }
}
