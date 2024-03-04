// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";

import {FeeDistributor} from "src/FeeDistributor.sol";
import {FeeSharing} from "src/FeeSharing.sol";

contract FeeDistributorTest is Test {
    event Claimed(
        uint256 indexed tokenId,
        uint256 indexed epoch,
        uint256 index,
        uint256 amount,
        address indexed account
    );

    event EpochAdded(uint256 epoch, uint256 rewards, bytes32 merkleRoot);

    FeeDistributor distributor;
    FeeSharing feeSharing;

    function setUp() public {
        feeSharing = new FeeSharing();
        distributor = new FeeDistributor(address(this), address(feeSharing));
    }
}

contract Claim is FeeDistributorTest {
    function test_revertsIf_merkleRootNotUpdated() public {
        bytes32[] memory proof = new bytes32[](0);
        vm.expectRevert(FeeDistributor.MerkleRootNotUpdated.selector);
        distributor.claim(0, 0, 0, 0, proof);
    }
}

contract IsClaimed is FeeDistributorTest {}

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
