pragma solidity ^0.4.24;

import "andromeda/contracts/Chain.sol";
import 'zeppelin-solidity/contracts/ownership/Ownable.sol';
import 'zeppelin-solidity/contracts/MerkleProof.sol';
import "zeppelin-solidity/contracts/ReentrancyGuard.sol";
import 'token-sale-contracts/contracts/Token.sol';
import 'token-sale-contracts/contracts/HumanStandardToken.sol';

contract Bank is Ownable, ReentrancyGuard {
  address public tokenAddress;
  address public chainAddress;

  constructor(
    address _tokenAddress,
    address _chainAddress
  ) public {
    tokenAddress = _tokenAddress;
    chainAddress = _chainAddress;
  }

  /**
   * @dev Callback for standard ERC-20 token accepting contracts and is called when accepting deposits.
   */

  function receiveApproval(
    address _from,
    uint256 _value,
    address _token,
    bytes _data
  ) public nonReentrant returns (bool success) {
    require(_token == tokenAddress);

    Token token = Token(tokenAddress);
    uint256 allowance = token.allowance(_from, this);

    require(allowance > 0);
    require(token.transferFrom(_from, this, allowance));

    return true;
  }

  function withdraw(
    uint256 _shard,
    uint256 _amount,
    uint256 _balance,
    bytes32[] _proof
  ) public nonReentrant returns (bool success) {
    bytes32 root = lastValidBlockRootForShard(_shard);

    bytes32 leafValue = keccak256(abi.encodePacked(tokenAddress, msg.sender, _balance));

    require(MerkleProof.verifyProof(_proof, root, leafValue));

    require(_amount <= _balance);

    Token token = Token(tokenAddress);

    require(token.transferFrom(this, msg.sender, _amount));

    return true;
  }

  /// @dev gets the last valid block root to prevent verifiers from withholding block headers
  /// @dev TODO: determine that the block is valid (i.e. 2/3 verifier signatures)
  function lastValidBlockRootForShard(uint256 _shard) internal view returns (bytes32) {
    Chain chain = Chain(chainAddress);
    uint256 blockHeight = chain.getBlockHeight() - 1;

    for (uint256 i = blockHeight; i >= 0; i--) {
      bytes32 root = chain.getBlockRoot(i, _shard);

      if (root != 0x0) {
        return root;
      }
    }

    return 0x0;
  }
}
