// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import "usingtellor/contracts/UsingTellor.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IAutopay.sol";
import "hardhat/console.sol";

contract SeedGenerator is UsingTellor {
  uint256 public seedPeriodLength;
  uint256 public randomNumberCount;
  uint256 public numberOfHashes;
  IAutopay public autopay;

  mapping(uint256 => Seed) public seeds;

  struct Seed {
    bytes32 seed;
    uint256 deadline;
    uint256 seedReward;
    uint256 numberOfHashes;
    address token;
    address lastSeeder;
  }

  event RandomNumberRequested(
    uint256 _seedId,
    uint256 _deadline,
    uint256 _seedReward,
    uint256 _oracleTip,
    address _token,
    bytes32 _queryId,
    bytes _queryData
  );
  event SeedRewardClaimed(uint256 _seedId, uint256 _seedReward, address _token);
  event SeedUpdated(uint256 _seedId);

  constructor(address payable _tellor, address _autopay, uint256 _seedPeriodLength, uint256 _numberOfHashes) UsingTellor(_tellor) {
      seedPeriodLength = _seedPeriodLength;
      numberOfHashes = _numberOfHashes;
      autopay = IAutopay(_autopay);
  }

  function claimSeedReward(uint256 _seedId) public {
      Seed storage _seed = seeds[_seedId];
      require(block.timestamp > _seed.deadline, "seed period still active");
      require(_seed.seedReward > 0, "seed reward already claimed");
      require(msg.sender == _seed.lastSeeder, "only last seeder address can claim seed reward");
      uint256 _seedReward = _seed.seedReward;
      _seed.seedReward = 0;
      IERC20(_seed.token).transfer(_seed.lastSeeder, _seedReward);
      emit SeedRewardClaimed(_seedId, _seedReward, _seed.token);
  }

  function requestRandomNumber(bytes32 _seedData, address _token, uint256 _seedReward, uint256 _oracleTip) public returns(bytes32, uint256) {
    bytes32 _seed = keccak256(abi.encode(_seedData, blockhash(block.number - 1)));
    seeds[randomNumberCount] = Seed(
        _seed,
        block.timestamp + seedPeriodLength,
        _seedReward,
        numberOfHashes,
        _token,
        msg.sender
        );
    bytes memory _queryData = abi.encode("TellorRNG", abi.encode(randomNumberCount));
    bytes32 _queryId = keccak256(_queryData);
    randomNumberCount++;
    require(IERC20(_token).transferFrom(msg.sender, address(this), _seedReward + _oracleTip));
    IERC20(_token).approve(address(autopay), _seedReward);
    autopay.tip(_token, _queryId, _oracleTip, _queryData);
    emit RandomNumberRequested(
      randomNumberCount - 1,
      block.timestamp + seedPeriodLength,
      _seedReward,
      _oracleTip,
      _token,
      _queryId,
      _queryData
      );
    return (_queryId, randomNumberCount - 1);
  }

  function updateSeed(uint256 _seedId, bytes32 _seedData) public {
      Seed storage _seed = seeds[_seedId];
      require(block.timestamp < _seed.deadline, "seed period expired");
      _seed.seed = keccak256(abi.encode(_seed.seed, _seedData));
      _seed.lastSeeder = msg.sender;
      emit SeedUpdated(_seedId);
  }

  // Getters
  function getSeed(uint256 _seedId) public view returns(Seed memory) {
      return seeds[_seedId];
  }

  function retrieveRandomNumberByQueryId(bytes32 _queryId)
      public
      view
      returns (
          bool _ifRetrieve,
          bytes memory _value,
          uint256 _timestampRetrieved
      )
  {
        _timestampRetrieved = getTimestampbyQueryIdandIndex(_queryId, 0);
        if (_timestampRetrieved == 0) return (false, bytes(''), 0);
        _value = retrieveData(_queryId, _timestampRetrieved);
        return (true, _value, _timestampRetrieved);
  }

  function retrieveRandomNumberBySeedId(uint256 _seedId)
    external
    view
    returns (
      bool _ifRetrieve,
      bytes memory _value,
      uint256 _timestampRetrieved
    )
  {
    bytes memory _queryData = abi.encode("TellorRNG", abi.encode(_seedId));
    bytes32 _queryId = keccak256(_queryData);
    _timestampRetrieved = getTimestampbyQueryIdandIndex(_queryId, 0);
    if (_timestampRetrieved == 0) return (false, bytes(''), 0);
    _value = retrieveData(_queryId, _timestampRetrieved);
    return (true, _value, _timestampRetrieved);
  }


}
