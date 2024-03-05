// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";

import {FeeDistributor} from "src/FeeDistributor.sol";
import {FeeSharing} from "src/FeeSharing.sol";

contract ReceiveSmartContract {
    receive() external payable {}
}

contract NoReceiveSmartContract {}

/// @dev The root and proof values used in these tests were generated using MerkleTreeJS
/// The values used were:
/// TokenId, Epoch, Index, Account, Amount
/// [1, 0, 0, '0xF62849F9A0B5Bf2913b396098F7c7019b51A820a', "1000000000000000000"]
/// [2, 0, 1, '0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9', "2000000000000000000"]
/// [3, 0, 2, '0xc7183455a4C133Ae270771860664b6B7ec320bB1', "3000000000000000000"]
/// [4, 0, 3, '0xa0Cb889707d426A7A386870A03bc70d1b0697598', "4000000000000000000"]
contract FeeDistributorTest is Test {
    event Claimed(
        uint256 indexed tokenId,
        uint256 indexed epoch,
        uint256 index,
        uint256 amount,
        address indexed account
    );

    event EpochAdded(uint256 epoch, uint256 rewards, bytes32 merkleRoot);

    /// @dev Root and tree generated using OpenZeppelin's MerkleTreeJS
    /// https://github.com/OpenZeppelin/merkle-tree
    bytes32 public constant MERKLE_ROOT =
        0x22bcd4344654afec237b4488eb4fa650030899bdedc06ff0d1b8e606affbd21c;

    FeeDistributor distributor;
    FeeSharing feeSharing;

    address public receiveContract1;
    address public receiveContract2;
    address public receiveContract3;
    address public receiveContract4;

    function setUp() public {
        feeSharing = new FeeSharing();
        distributor = new FeeDistributor(address(this), address(feeSharing));

        receiveContract1 = address(new ReceiveSmartContract());
        receiveContract2 = address(new ReceiveSmartContract());
        receiveContract3 = address(new ReceiveSmartContract());
        receiveContract4 = address(new ReceiveSmartContract());
    }

    function _registerContractAndEpoch() internal {
        vm.prank(receiveContract1);
        feeSharing.register(receiveContract1);

        distributor.addEpoch{value: 100 ether}(MERKLE_ROOT);
    }
}

contract Claim is FeeDistributorTest {
    function test_revertsIf_merkleRootNotUpdated() public {
        bytes32[] memory proof = new bytes32[](0);
        vm.expectRevert(FeeDistributor.MerkleRootNotUpdated.selector);
        distributor.claim(0, 0, 0, 0, proof);
    }

    function test_revertsIf_notOwner() public {
        _registerContractAndEpoch();

        bytes32[] memory proof = new bytes32[](0);
        vm.expectRevert(FeeDistributor.NotOwner.selector);
        distributor.claim(1, 0, 0, 0, proof);
    }

    function test_revertsIf_alreadyClaimed() public {
        _registerContractAndEpoch();

        bytes32[] memory proof = new bytes32[](2);
        proof[
            0
        ] = 0x737fe4b77743fb3d8cebe269acac9609e07d6968f4fa86c8ce5359f2da182a08;
        proof[
            1
        ] = 0x32ada947317cca78420d729aafd40b37348530914e939ba5338bada9b5d32b87;

        vm.startPrank(receiveContract1);
        distributor.claim(1, 0, 0, 1000000000000000000, proof);

        vm.expectRevert(FeeDistributor.AlreadyClaimed.selector);
        distributor.claim(1, 0, 0, 1000000000000000000, proof);
    }

    function test_revertsIf_invalidProof() public {
        _registerContractAndEpoch();

        bytes32[] memory proof = new bytes32[](2);
        proof[
            0
        ] = 0x6c2257b38f514b436d5996cdc9e2f4e894b9253b7a85d9c9b79fe002f181c987;
        proof[
            1
        ] = 0x8d872799f33f987774ed3312566530c677ebffc8a8f827d01fe0a09e1fcc024b;

        vm.expectRevert(FeeDistributor.InvalidProof.selector);
        vm.startPrank(receiveContract1);
        distributor.claim(1, 0, 0, 1000000000000000000, proof);
    }

    function test_revertsIf_unableToSendRewards() public {
        address noReceive = address(new NoReceiveSmartContract());

        vm.prank(noReceive);
        feeSharing.register(noReceive);
        distributor.addEpoch{value: 100 ether}(
            0x9551430a2790bc99ca90a1d9a6e1e6132c815f389c85415ab8beb6db625e9b95
        );

        bytes32[] memory proof = new bytes32[](2);
        proof[
            0
        ] = 0x67a83928c147a415f2e0c1b6d61ef932f2d440de22519eab821f5b0a37a6b576;
        proof[
            1
        ] = 0xc503bbb961dae8c65196a5625d50cbd68d54acb5173096354612e18e5a459cb5;

        vm.expectRevert(FeeDistributor.UnableToSendRewards.selector);
        vm.startPrank(noReceive);
        distributor.claim(1, 0, 0, 1000000000000000000, proof);
    }

    function test_succesful_here() public {
        _registerContractAndEpoch();

        uint256 amount = 1000000000000000000;
        uint256 balanceReceiverBefore = receiveContract1.balance;
        bytes32[] memory proof = new bytes32[](2);
        proof[
            0
        ] = 0x737fe4b77743fb3d8cebe269acac9609e07d6968f4fa86c8ce5359f2da182a08;
        proof[
            1
        ] = 0x32ada947317cca78420d729aafd40b37348530914e939ba5338bada9b5d32b87;

        vm.expectEmit();
        emit Claimed(1, 0, 0, amount, receiveContract1);
        vm.prank(receiveContract1);
        distributor.claim(1, 0, 0, amount, proof);

        assertEq(receiveContract1.balance, balanceReceiverBefore + amount);
    }
}

contract IsClaimed is FeeDistributorTest {
    function test_successful_notClaimed() public {
        _registerContractAndEpoch();

        assertFalse(distributor.isClaimed(0, 0));
    }

    function test_successful_claimed() public {
        _registerContractAndEpoch();

        bytes32[] memory proof = new bytes32[](2);
        proof[
            0
        ] = 0x737fe4b77743fb3d8cebe269acac9609e07d6968f4fa86c8ce5359f2da182a08;
        proof[
            1
        ] = 0x32ada947317cca78420d729aafd40b37348530914e939ba5338bada9b5d32b87;

        vm.prank(receiveContract1);
        distributor.claim(1, 0, 0, 1000000000000000000, proof);

        assertTrue(distributor.isClaimed(0, 0));
    }
}

contract AddEpoch is FeeDistributorTest {
    function test_revertsIf_notOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(makeAddr("random-caller"));
        distributor.addEpoch(bytes32("new-root"));
    }

    function test_revertsIf_emptyValue() public {
        vm.expectRevert(FeeDistributor.InsufficientRewards.selector);
        distributor.addEpoch(bytes32("new-root"));
    }

    function test_successful() public {
        assertEq(distributor.epochs(), 0);
        assertEq(distributor.rewardsForEpoch(0), 0);
        assertEq(distributor.merkleRootForEpoch(0), 0);

        bytes32 root = bytes32("new-root");

        distributor.addEpoch{value: 1 ether}(root);

        assertEq(distributor.epochs(), 1);
        assertEq(distributor.rewardsForEpoch(0), 1 ether);
        assertEq(distributor.merkleRootForEpoch(0), root);
    }
}
