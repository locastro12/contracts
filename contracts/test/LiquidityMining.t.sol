// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.23;

import "ds-test/test.sol";
import "forge-std/Vm.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { Auth, Authority } from "solmate/auth/Auth.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { FlywheelStaticRewards } from "flywheel-v2/rewards/FlywheelStaticRewards.sol";
import { CToken as ICToken } from "fuse-flywheel/FuseFlywheelLensRouter.sol";
import "flywheel/FlywheelCore.sol";
import "../compound/CTokenInterfaces.sol";
import "../midas/strategies/flywheel/MidasFlywheel.sol";
import "../midas/strategies/flywheel/MidasFlywheelLensRouter.sol";

import { CErc20 } from "../compound/CErc20.sol";
import { CToken } from "../compound/CToken.sol";
import { WhitePaperInterestRateModel } from "../compound/WhitePaperInterestRateModel.sol";
import { Unitroller } from "../compound/Unitroller.sol";
import { Comptroller } from "../compound/Comptroller.sol";
import { CErc20Delegate } from "../compound/CErc20Delegate.sol";
import { CErc20Delegator } from "../compound/CErc20Delegator.sol";
import { RewardsDistributorDelegate } from "../compound/RewardsDistributorDelegate.sol";
import { RewardsDistributorDelegator } from "../compound/RewardsDistributorDelegator.sol";
import { ComptrollerInterface } from "../compound/ComptrollerInterface.sol";
import { InterestRateModel } from "../compound/InterestRateModel.sol";
import { FuseFeeDistributor } from "../FuseFeeDistributor.sol";
import { FusePoolDirectory } from "../FusePoolDirectory.sol";
import { MockPriceOracle } from "../oracles/1337/MockPriceOracle.sol";

contract LiquidityMiningTest is DSTest {
  Vm public constant vm = Vm(HEVM_ADDRESS);

  MockERC20 underlyingToken;
  MockERC20 rewardToken;

  WhitePaperInterestRateModel interestModel;
  Comptroller comptroller;
  CErc20Delegate cErc20Delegate;
  CErc20 cErc20;
  FuseFeeDistributor fuseAdmin;
  FusePoolDirectory fusePoolDirectory;

  MidasFlywheel flywheel;
  FlywheelStaticRewards rewards;
  MidasFlywheelLensRouter flywheelClaimer;

  address user = address(this);

  uint8 baseDecimal;
  uint8 rewardDecimal;

  address[] markets;
  address[] emptyAddresses;
  address[] newUnitroller;
  bool[] falseBoolArray;
  bool[] trueBoolArray;
  address[] newImplementation;
  MidasFlywheelCore[] flywheelsToClaim;

  function setUpBaseContracts(uint8 _baseDecimal, uint8 _rewardDecimal) public {
    baseDecimal = _baseDecimal;
    rewardDecimal = _rewardDecimal;
    underlyingToken = new MockERC20("UnderlyingToken", "UT", baseDecimal);
    rewardToken = new MockERC20("RewardToken", "RT", rewardDecimal);
    interestModel = new WhitePaperInterestRateModel(2343665, 1 * 10**baseDecimal, 1 * 10**baseDecimal);
    fuseAdmin = new FuseFeeDistributor();
    fuseAdmin.initialize(1 * 10**(baseDecimal - 2));
    fusePoolDirectory = new FusePoolDirectory();
    fusePoolDirectory.initialize(false, emptyAddresses);
    cErc20Delegate = new CErc20Delegate();
  }

  function setUpPoolAndMarket() public {
    MockPriceOracle priceOracle = new MockPriceOracle(10);
    emptyAddresses.push(address(0));
    Comptroller tempComptroller = new Comptroller(payable(fuseAdmin));
    newUnitroller.push(address(tempComptroller));
    trueBoolArray.push(true);
    falseBoolArray.push(false);
    fuseAdmin._editComptrollerImplementationWhitelist(emptyAddresses, newUnitroller, trueBoolArray);
    (uint256 index, address comptrollerAddress) = fusePoolDirectory.deployPool(
      "TestPool",
      address(tempComptroller),
      abi.encode(payable(address(fuseAdmin))),
      false,
      0.1e18,
      1.1e18,
      address(priceOracle)
    );

    Unitroller(payable(comptrollerAddress))._acceptAdmin();
    comptroller = Comptroller(comptrollerAddress);

    newImplementation.push(address(cErc20Delegate));
    fuseAdmin._editCErc20DelegateWhitelist(emptyAddresses, newImplementation, falseBoolArray, trueBoolArray);
    vm.roll(1);
    comptroller._deployMarket(
      false,
      abi.encode(
        address(underlyingToken),
        ComptrollerInterface(comptrollerAddress),
        payable(address(fuseAdmin)),
        InterestRateModel(address(interestModel)),
        "CUnderlyingToken",
        "CUT",
        address(cErc20Delegate),
        "",
        uint256(1),
        uint256(0)
      ),
      0.9e18
    );

    CTokenInterface[] memory allMarkets = comptroller.getAllMarkets();
    cErc20 = CErc20(address(allMarkets[allMarkets.length - 1]));
  }

  function setUpFlywheel() public {
    flywheel = new MidasFlywheel();
    flywheel.initialize(rewardToken, FlywheelStaticRewards(address(0)), IFlywheelBooster(address(0)), address(this));
    rewards = new FlywheelStaticRewards(FlywheelCore(address(flywheel)), address(this), Authority(address(0)));
    flywheel.setFlywheelRewards(rewards);

    flywheelClaimer = new MidasFlywheelLensRouter();

    flywheel.addStrategyForRewards(ERC20(address(cErc20)));

    // add flywheel as rewardsDistributor to call flywheelPreBorrowAction / flywheelPreSupplyAction
    require(comptroller._addRewardsDistributor(address(flywheel)) == 0);

    // seed rewards to flywheel
    rewardToken.mint(address(rewards), 100 * 10**rewardDecimal);

    // Start reward distribution at 1 token per second
    rewards.setRewardsInfo(
      ERC20(address(cErc20)),
      FlywheelStaticRewards.RewardsInfo({ rewardsPerSecond: uint224(1 * 10**rewardDecimal), rewardsEndTimestamp: 0 })
    );

    // preperation for a later call
    flywheelsToClaim.push(MidasFlywheelCore(address(flywheel)));
  }

  function _initialize(uint8 baseDecimal, uint8 rewardDecimal) internal {
    setUpBaseContracts(baseDecimal, rewardDecimal);
    setUpPoolAndMarket();
    setUpFlywheel();
    deposit(1 * 10**baseDecimal);
    vm.warp(block.timestamp + 1);
  }

  function deposit(uint256 _amount) public {
    underlyingToken.mint(user, _amount);
    underlyingToken.approve(address(cErc20), _amount);
    comptroller.enterMarkets(markets);
    cErc20.mint(_amount);
  }

  function _testIntegration() internal {
    // store expected rewards per token (1 token per second over total supply)
    uint256 rewardsPerToken = (1 * 10**rewardDecimal * 1 * 10**baseDecimal) / cErc20.totalSupply();

    // store expected user rewards (user balance times reward per second over 1 token)
    uint256 userRewards = (rewardsPerToken * cErc20.balanceOf(user)) / (1 * 10**baseDecimal);

    // accrue rewards and check against expected
    require(flywheel.accrue(ERC20(address(cErc20)), user) == userRewards);

    // check market index
    (uint224 index, ) = flywheel.strategyState(ERC20(address(cErc20)));
    require(index == flywheel.ONE() + rewardsPerToken);

    // claim and check user balance
    flywheelClaimer.getUnclaimedRewardsForMarket(user, CErc20Token(address(cErc20)), flywheelsToClaim, trueBoolArray);
    require(rewardToken.balanceOf(user) == userRewards);

    // mint more tokens by user and rerun test
    deposit(1e6 * 10**baseDecimal);

    // for next test, advance 10 seconds instead of 1 (multiply expectations by 10)
    uint256 rewardsPerToken2 = (10 * 10**rewardDecimal * 1 * 10**baseDecimal) / cErc20.totalSupply();
    vm.warp(block.timestamp + 10);

    uint256 userRewards2 = (rewardsPerToken2 * cErc20.balanceOf(user)) / (1 * 10**baseDecimal);

    // accrue all unclaimed rewards and claim them
    flywheelClaimer.getUnclaimedRewardsForMarket(user, CErc20Token(address(cErc20)), flywheelsToClaim, trueBoolArray);

    // user balance should accumulate from both rewards
    require(rewardToken.balanceOf(user) == userRewards + userRewards2, "balance mismatch");
  }

  function testIntegrationRewardStandard() public {
    _initialize(6, 18);
    _testIntegration();
  }

  function testIntegrationBaseStandard() public {
    _initialize(18, 6);
    _testIntegration();
  }

  function testIntegrationNoStandard() public {
    _initialize(6, 8);
    _testIntegration();
  }

  function testIntegrationStandard() public {
    _initialize(18, 18);
    _testIntegration();
  }
}
