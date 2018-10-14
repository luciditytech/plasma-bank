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
  uint256 public balance;

  struct Account {
    uint256 withdrawing;
    uint256 withdrawingAt;
    uint256 withdrawingShard;
  }

  mapping(address => Account) public accounts;

  constructor(
    address _tokenAddress,
    address _chainAddress
  ) public {
    tokenAddress = _tokenAddress;
    chainAddress = _chainAddress;
  }

  /**
   * @dev Callback for standard ERC-20 tokens when accepting deposits.
   */

  function receiveApproval (
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

    balance += allowance;

    return true;
  }

  /**
   * @dev Initiates an exit by providing proof-of-balance against last valid sidechain block.
   */

  function startWithdrawal(
    uint256 _shard,
    uint256 _amount,
    bytes32[] _proof
  ) public nonReentrant returns (bool success) {
    Chain chain = Chain(chainAddress);
    uint256 blockHeight = chain.getBlockHeight() - 1;

    bytes32 root = chain.getBlockRoot(blockHeight, _shard);

    bytes32 leafValue = keccak256(abi.encodePacked(tokenAddress, msg.sender, _amount));

    require(MerkleProof.verifyProof(_proof, root, leafValue));

    Account storage account = accounts[msg.sender];

    require(account.withdrawing == 0);

    account.withdrawing = _amount;
    account.withdrawingAt = block.number;
    account.withdrawingShard = _shard;

    return true;
  }

  /**
   * @dev During an exit's challenge period, anyone is able to submit proof of lower balance against the last valid block.
   */

  function challengeWithdrawal(
    address _withdrawer,
    uint256 _balance,
    bytes32[] _proof
  ) public nonReentrant returns (bool success) {
    Account storage account = accounts[_withdrawer];
    require(account.withdrawing > 0);

    require(account.withdrawing > _balance);

    uint256 waitingRounds = 2;
    uint256 challengePeriod = chain.blocksPerPhase() * (waitingRounds * 2);

    require((block.number - account.withdrawingAt) < challengePeriod);

    Chain chain = Chain(chainAddress);
    uint256 blockHeight = chain.getBlockHeight() - 1;

    bytes32 root = chain.getBlockRoot(blockHeight, account.withdrawingShard);
  
    bytes32 leafValue = keccak256(abi.encodePacked(tokenAddress, _withdrawer, _balance));

    require(MerkleProof.verifyProof(_proof, root, leafValue));

    uint256 bounty = uint256((account.withdrawing * 2) / 20);

    Token token = Token(tokenAddress);

    require(token.transferFrom(this, msg.sender, bounty));

    balance -= bounty;

    account.withdrawing = 0;
    account.withdrawingAt = 0;

    return true;
  }

  /**
   * @dev After an exit's challenge period, withdraw the funds if unchallenged.
   */

  function completeWithdrawal() public nonReentrant returns (bool success) {
    Chain chain = Chain(chainAddress);

    Account storage account = accounts[msg.sender];
    require(account.withdrawing > 0);

    uint256 waitingRounds = 2;
    uint256 challengePeriod = chain.blocksPerPhase() * (waitingRounds * 2);

    require((block.number - account.withdrawingAt) >= challengePeriod);

    Token token = Token(tokenAddress);

    require(token.transferFrom(this, msg.sender, account.withdrawing));

    balance -= account.withdrawing;

    account.withdrawing = 0;
    account.withdrawingAt = 0;

    return true;
  }
}
