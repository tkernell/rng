// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import "usingtellor/contracts/UsingTellor.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";

interface IAutopay {
    function tip(
        address _token,
        bytes32 _queryId,
        uint256 _amount
    ) external;
}

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

  constructor(address payable _tellor, address _autopay, uint256 _seedPeriodLength, uint256 _numberOfHashes) UsingTellor(_tellor) {
      seedPeriodLength = _seedPeriodLength;
      numberOfHashes = _numberOfHashes;
      autopay = IAutopay(_autopay);
  }

  function requestRandomNumber(bytes32 _seedData, address _token, uint256 _seedReward, uint256 _oracleTip) public returns(bytes32) {
    bytes32 _seed = keccak256(abi.encode(_seedData, blockhash(block.number)));
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
    autopay.tip(_token, _queryId, _oracleTip);
    return _queryId;
  }

  function updateSeed(uint256 _seedId, bytes32 _seedData) public {
      Seed storage _seed = seeds[_seedId];
      require(block.timestamp < _seed.deadline);
      _seed.seed = keccak256(abi.encode(_seed.seed, _seedData));
  }

  function claimSeedReward(uint256 _seedId) public {
      Seed storage _seed = seeds[_seedId];
      require(block.timestamp > _seed.deadline);
      require(_seed.seedReward > 0);
      require(msg.sender == _seed.lastSeeder);
      uint256 _seedReward = _seed.seedReward;
      _seed.seedReward = 0;
      IERC20(_seed.token).transfer(_seed.lastSeeder, _seedReward);
  }

}
