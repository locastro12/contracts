import { parseEther } from "ethers/lib/utils";
import { task, types } from "hardhat/config";

// npx hardhat strategy:create --strategy-name AlpacaERC4626 --underlying "" --name Plugin-Alpaca-USDC --symbol pAlUSDC --creator deployer --other-params "" --network localhost

task("strategy:create", "Create ERC4626 Strategy")
  .addParam("strategyName", "Name of the ERC4626 strategy", undefined, types.string)
  .addParam("underlying", "Address of the underlying token", undefined, types.string)
  .addParam("name", "Name of the Token", undefined, types.string)
  .addParam("symbol", "Symbol of the Token", undefined, types.string)
  .addParam("creator", "Deployer Address", "deployer", types.string)
  .addOptionalParam(
    "otherParams",
    "other params that might be required to construct the strategy",
    undefined,
    types.string
  )
  .setAction(async (taskArgs, hre) => {
    const otherParams = taskArgs.otherParams ? taskArgs.otherParams.split(",") : null;
    let deployArgs;
    if (otherParams) {
      deployArgs = [taskArgs.underlying, taskArgs.name, taskArgs.symbol, ...otherParams];
    } else {
      deployArgs = [taskArgs.underlying, taskArgs.name, taskArgs.symbol];
    }

    const deployment = await hre.deployments.deploy(taskArgs.strategyName, {
      from: taskArgs.creator,
      args: deployArgs,
      log: true,
    });

    console.log("ERC4626 Strategy: ", deployment.address);
  });
