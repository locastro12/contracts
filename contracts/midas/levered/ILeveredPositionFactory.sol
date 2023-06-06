// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { IRedemptionStrategy } from "../../liquidators/IRedemptionStrategy.sol";
import { ICErc20 } from "../../external/compound/ICErc20.sol";
import { LeveredPosition } from "./LeveredPosition.sol";
import { IFuseFeeDistributor } from "../../compound/IFuseFeeDistributor.sol";
import { ILiquidatorsRegistry } from "../../liquidators/registry/ILiquidatorsRegistry.sol";

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

interface ILeveredPositionFactoryStorage {
  function fuseFeeDistributor() external view returns (IFuseFeeDistributor);

  function liquidatorsRegistry() external view returns (ILiquidatorsRegistry);

  function blocksPerYear() external view returns (uint256);

  function owner() external view returns (address);
}

interface ILeveredPositionFactoryBase {
  function _setSlippages(
    IERC20Upgradeable[] calldata inputTokens,
    IERC20Upgradeable[] calldata outputTokens,
    uint256[] calldata slippages
  ) external;

  function _setLiquidatorsRegistry(ILiquidatorsRegistry _liquidatorsRegistry) external;

  function _setPairWhitelisted(
    ICErc20 _collateralMarket,
    ICErc20 _stableMarket,
    bool _whitelisted
  ) external;
}

interface ILeveredPositionFactoryExtension {
  function getRedemptionStrategies(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken)
    external
    view
    returns (IRedemptionStrategy[] memory strategies, bytes[] memory strategiesData);

  function getMinBorrowNative() external view returns (uint256);

  function createPosition(ICErc20 _collateralMarket, ICErc20 _stableMarket) external returns (LeveredPosition);

  function createAndFundPosition(
    ICErc20 _collateralMarket,
    ICErc20 _stableMarket,
    IERC20Upgradeable _fundingAsset,
    uint256 _fundingAmount
  ) external returns (LeveredPosition);

  function createAndFundPositionAtRatio(
    ICErc20 _collateralMarket,
    ICErc20 _stableMarket,
    IERC20Upgradeable _fundingAsset,
    uint256 _fundingAmount,
    uint256 _leverageRatio
  ) external returns (LeveredPosition);

  function removeClosedPosition(address closedPosition) external returns (bool removed);

  function isFundingAllowed(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken) external view returns (bool);

  function getSlippage(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken) external view returns (uint256);

  function getPositionsByAccount(address account) external view returns (address[] memory);

  function getAccountsWithOpenPositions() external view returns (address[] memory);

  function getWhitelistedCollateralMarkets() external view returns (address[] memory);

  function getBorrowableMarketsByCollateral(ICErc20 _collateralMarket) external view returns (address[] memory);
}

interface ILeveredPositionFactory is
  ILeveredPositionFactoryStorage,
  ILeveredPositionFactoryBase,
  ILeveredPositionFactoryExtension
{}