// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "openzeppelin/utils/cryptography/MerkleProof.sol";
import "openzeppelin/access/Ownable.sol";
import "openzeppelin/security/ReentrancyGuard.sol";

import {FeeSharing} from "./FeeSharing.sol";

contract FeeDistributor is Ownable, ReentrancyGuard {
    /// @dev Rewards have already been claimed
    error AlreadyClaimed();

    /// @dev Epoch already added
    error EpochAlreadyAdded();

    /// @dev Invalid proof submitted
    error InvalidProof();

    /// @dev Cannot send 0 funds for rewards
    error InsufficientRewards();

    /// @dev Merkle Root for epoch has not been added yet
    error MerkleRootNotUpdated();

    /// @dev Caller is not the owner of the token
    error NotOwner();

    /// @dev Failed to distribute rewards
    error UnableToSendRewards();

    /// @dev Emitted when a user claims their rewards
    event Claimed(
        uint256 indexed tokenId,
        uint256 indexed epoch,
        uint256 index,
        uint256 amount,
        address indexed account
    );

    /// @dev Emitted when a new merkle root is added to an epoch
    event EpochAdded(uint256 epoch, uint256 rewards, bytes32 merkleRoot);

    /// @dev The ERC721 contract for rewards accrual
    address public immutable feeSharing;

    /// @dev Number of epochs
    uint256 public epochs;

    /// @notice Mapping of epoch to merkle root
    mapping(uint256 => bytes32) public merkleRootForEpoch;

    /// @notice Mapping of epoch to total rewards
    mapping(uint256 => uint256) public rewardsForEpoch;

    /// @dev Nested mapping of epoch to claim bit-map
    mapping(uint256 => mapping(uint256 => uint256)) private claimedBitMap;

    constructor(address _owner, address _feeSharing) {
        _transferOwnership(_owner);
        feeSharing = _feeSharing;
    }

    /// @dev Called to claim rewards for an epoch
    /// @param tokenId The ID of the NFT to claim rewards for
    /// @param epoch The epoch to claim rewards for
    /// @param index The index in the merkle tree
    /// @param amount The amount of tokens to claim
    /// @param merkleProof The proof to claim rewards by
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
            bytes.concat(
                keccak256(abi.encode(tokenId, epoch, index, msg.sender, amount))
            )
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

    /// @dev Called to check if a given index has been claimed for a specific epoch
    /// @param epoch The epoch to query for
    /// @param index The index to query for
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

    /// @dev Called by owner to add a new epoch and merkle root
    /// @param merkleRoot The root of the merkle tree
    function addEpoch(bytes32 merkleRoot) external payable onlyOwner {
        if (msg.value == 0) revert InsufficientRewards();
        if (merkleRootForEpoch[epochs] != 0) revert EpochAlreadyAdded(); // Unreachable
        merkleRootForEpoch[epochs] = merkleRoot;
        rewardsForEpoch[epochs] = msg.value;

        emit EpochAdded(epochs, msg.value, merkleRoot);

        unchecked {
            epochs++;
        }
    }

    /// @dev Called to set an index for a given epoch to claimed
    /// @param epoch The given epoch
    /// @param index The index to set as claimed
    function _setClaimed(uint256 epoch, uint256 index) internal {
        uint256 claimedWordIndex = index >> 8;
        uint256 claimedBitIndex = index & 0xff;
        claimedBitMap[epoch][claimedWordIndex] |= (1 << claimedBitIndex);
    }
}
