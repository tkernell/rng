const {
  expect
} = require("chai");
const {
  ethers
} = require("hardhat");
const h = require("./helpers/helpers");

const SEED_PERIOD_LENGTH = 300
const NUMBER_OF_HASHES = 1000000

describe("Tellor Random Number Generator", function() {

  let rng, tellor, autopay;
  let accounts;

  beforeEach(async function() {
    const TellorPlayground = await ethers.getContractFactory("TellorPlayground");
    tellor = await TellorPlayground.deploy();
    accounts = await ethers.getSigners();
    await tellor.deployed();
    const Autopay = await ethers.getContractFactory("Autopay")
    autopay = await Autopay.deploy(tellor.address, accounts[0].address, 10)
    await autopay.deployed()
    const RNG = await ethers.getContractFactory("SeedGenerator")
    rng = await RNG.deploy(tellor.address, autopay.address, SEED_PERIOD_LENGTH, NUMBER_OF_HASHES)
  });

  it("constructor", async function() {
    expect(await rng.tellor()).to.equal(tellor.address);
    expect(await rng.seedPeriodLength()).to.equal(SEED_PERIOD_LENGTH)
    expect(await rng.numberOfHashes()).to.equal(NUMBER_OF_HASHES)
    expect(await rng.autopay()).to.equal(autopay.address)
  });

  it("requestRandomNumber", async function() {
    await tellor.faucet(accounts[1].address)
    await tellor.connect(accounts[1]).approve(rng.address, h.toWei("3"))
    expect(await rng.randomNumberCount()).to.equal(0)
    await h.expectThrow(rng.connect(accounts[1]).requestRandomNumber(h.hash("seedData"), tellor.address, h.toWei("100"), h.toWei("1"))) // insufficient approval
    blocky0 = await h.getBlock()
    await rng.connect(accounts[1]).requestRandomNumber(h.hash("seedData"), tellor.address, h.toWei("2"), h.toWei("1"))
    blocky1 = await h.getBlock()
    expect(await rng.randomNumberCount()).to.equal(1)
    seed = await rng.getSeed(0)
    abiCoder = new ethers.utils.AbiCoder
    expect(seed.seed).to.equal(ethers.utils.keccak256(abiCoder.encode(['bytes32', 'bytes32'], [h.hash("seedData"), blocky0.hash])))
    expect(seed.deadline).to.equal(blocky1.timestamp + SEED_PERIOD_LENGTH)
    expect(seed.seedReward).to.equal(h.toWei("2"))
    expect(seed.numberOfHashes).to.equal(NUMBER_OF_HASHES)
    expect(seed.token).to.equal(tellor.address)
    expect(seed.lastSeeder).to.equal(accounts[1].address)
    queryData = h.encodeQueryData(['string', 'uint256'], ["TellorRNG", 0])
    queryId = ethers.utils.keccak256(queryData)
    expect(await autopay.getCurrentTip(queryId, tellor.address)).to.equal(h.toWei("1"))
    expect(await tellor.balanceOf(rng.address)).to.equal(h.toWei("2"))
    expect(await tellor.balanceOf(autopay.address)).to.equal(h.toWei("1"))
  });

  it("claimSeedReward", async function() {
    await tellor.faucet(accounts[1].address)
    await tellor.connect(accounts[1]).approve(rng.address, h.toWei("3"))
    blocky0 = await h.getBlock()
    await rng.connect(accounts[1]).requestRandomNumber(h.hash("seedData"), tellor.address, h.toWei("2"), h.toWei("1"))
    await rng.connect(accounts[2]).updateSeed(0, h.hash("moreSeedData"))
    await h.expectThrow(rng.connect(accounts[2]).claimSeedReward(0)) // seed period still active
    await h.advanceTime(SEED_PERIOD_LENGTH)
    await h.expectThrow(rng.connect(accounts[1]).claimSeedReward(0)) // only last seeder address can claim seed reward
    seedDetails = await rng.getSeed(0)
    expect(seedDetails.seedReward).to.equal(h.toWei("2"))
    await rng.connect(accounts[2]).claimSeedReward(0)
    seedDetails = await rng.getSeed(0)
    expect(seedDetails.seedReward).to.equal(0)
    await h.expectThrow(rng.connect(accounts[2]).claimSeedReward(0)) // seed reward already claimed
  });

  it("updateSeed", async function() {
    await tellor.faucet(accounts[1].address)
    await tellor.connect(accounts[1]).approve(rng.address, h.toWei("3"))
    blocky0 = await h.getBlock()
    await rng.connect(accounts[1]).requestRandomNumber(h.hash("seedData"), tellor.address, h.toWei("2"), h.toWei("1"))
    seedDetails = await rng.getSeed(0)
    abiCoder = new ethers.utils.AbiCoder
    seed0 = ethers.utils.keccak256(abiCoder.encode(['bytes32', 'bytes32'], [h.hash('seedData'), blocky0.hash]))
    expect(seedDetails.seed).to.equal(seed0)
    expect(seedDetails.lastSeeder).to.equal(accounts[1].address)
    await rng.connect(accounts[2]).updateSeed(0, h.hash("moreSeedData"))
    seedDetails = await rng.getSeed(0)
    seed1 = ethers.utils.keccak256(abiCoder.encode(['bytes32', 'bytes32'], [seed0, h.hash("moreSeedData")]))
    expect(seedDetails.seed).to.equal(seed1)
    expect(seedDetails.lastSeeder).to.equal(accounts[2].address)
    await h.advanceTime(SEED_PERIOD_LENGTH)
    await h.expectThrow(rng.connect(accounts[2]).updateSeed(0, h.hash("moreSeedData"))) // seed period expired

  });


});
