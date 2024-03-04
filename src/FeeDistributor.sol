// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "openzeppelin/utils/cryptography/MerkleProof.sol";
import "openzeppelin/access/Ownable.sol";
import "openzeppelin/security/ReentrancyGuard.sol";

import {FeeSharing} from "./FeeSharing.sol";

contract FeeDistributor is Ownable, ReentrancyGuard {
    error AlreadyClaimed();
    error EpochAlreadyAdded();
    error InvalidProof();
    error InvalidTokenId();
    error InsufficientRewards();
    error MerkleRootNotUpdated();
    error NotOwner();
    error UnableToSendRewards();

    event Claimed(
        uint256 indexed tokenId,
        uint256 indexed epoch,
        uint256 index,
        uint256 amount,
        address indexed account
    );

    event EpochAdded(uint256 epoch, uint256 rewards, bytes32 merkleRoot);

    address public immutable feeSharing;

    uint256 public epochs;
    mapping(uint256 => bytes32) public merkleRootForEpoch;
    mapping(uint256 => uint256) public rewardsForEpoch;

    mapping(uint256 => mapping(uint256 => uint256)) private claimedBitMap;

    constructor(address _owner, address _feeSharing) {
        _transferOwnership(_owner);
        feeSharing = _feeSharing;
    }

    function claim(
        uint256 tokenId,
        uint256 epoch,
        uint256 index,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) public nonReentrant {
        if (merkleRootForEpoch[epoch] == 0) revert MerkleRootNotUpdated();
        if (isClaimed(epoch, index)) revert AlreadyClaimed();
        if (FeeSharing(feeSharing).ownerOf(tokenId) != msg.sender) {
            revert NotOwner();
        }

        // Check that the given parameters match the given Proof
        bytes32 node = keccak256(
            abi.encodePacked(tokenId, epoch, index, msg.sender, amount)
        );
        if (!MerkleProof.verify(merkleProof, merkleRootForEpoch[epoch], node)) {
            revert InvalidProof();
        }

        _setClaimed(epoch, index);
        rewardsForEpoch[epoch] -= amount;
        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) revert UnableToSendRewards();

        emit Claimed(tokenId, epoch, index, amount, msg.sender);
    }

    function isClaimed(
        uint256 epoch,
        uint256 index
    ) public view returns (bool) {
        uint256 claimedWordIndex = index >> 8;
        uint256 claimedBitIndex = index & 0xff;
        uint256 claimedWord = claimedBitMap[epoch][claimedWordIndex];
        uint256 mask = (1 << claimedBitIndex);
        return claimedWord & mask != 0;
    }

    function _setClaimed(uint256 epoch, uint256 index) internal {
        uint256 claimedWordIndex = index >> 8;
        uint256 claimedBitIndex = index & 0xff;
        claimedBitMap[epoch][claimedWordIndex] |= (1 << claimedBitIndex);
    }

    function addEpoch(bytes32 merkleRoot) external payable onlyOwner {
        if (msg.value == 0) revert InsufficientRewards();
        if (merkleRootForEpoch[epochs] != 0) revert EpochAlreadyAdded();
        merkleRootForEpoch[epochs] = merkleRoot;
        rewardsForEpoch[epochs] = msg.value;

        emit EpochAdded(epochs, msg.value, merkleRoot);

        unchecked {
            epochs++;
        }
    }
}
