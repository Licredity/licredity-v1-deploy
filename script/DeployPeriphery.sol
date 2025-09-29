//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.26;

import {Script} from "@forge-std/Script.sol";
import {console} from "@forge-std/console.sol";
import {PeripheryDeploymentConfig} from "./TomlConfig.sol";
import {PositionManager} from "@licredity-v1-periphery/PositionManager.sol";
import {IAllowanceTransfer} from "@licredity-v1-periphery/interfaces/external/IAllowanceTransfer.sol";
import {IPoolManager} from "@uniswap-v4-core/interfaces/IPoolManager.sol";

contract DeployPeriphery is Script {
    function run() external {
        string memory toml = vm.readFile("./periphery_deployment.toml");

        string memory chain = vm.envString("CHAIN");

        bytes memory data = vm.parseToml(toml, string.concat("$.", chain));

        PeripheryDeploymentConfig memory deployment = abi.decode(data, (PeripheryDeploymentConfig));

        // Load deployment settings
        console.log("Governor Address:", deployment.governor);
        console.log("Permit2 Address:", deployment.permit2);
        console.log("Pool Manager Address:", deployment.poolManager);
        console.log("Position Manager Address:", deployment.positionManager);

        vm.startBroadcast();
        PositionManager periphery = new PositionManager(
            deployment.governor,
            IPoolManager(deployment.poolManager),
            deployment.positionManager,
            IAllowanceTransfer(deployment.permit2)
        );
        vm.stopBroadcast();

        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("Periphery deployed at:", address(periphery));
    }
}
