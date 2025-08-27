//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.26;

import "@forge-std/Script.sol";
import "@forge-std/console.sol";
import {Licredity} from "@licredity-v1-core/Licredity.sol";
import {LicredityDeploymentConfig} from "./TomlConfig.sol";

contract DeployLicredity is Script {
    function run() external {
        string memory toml = vm.readFile("./licredity_deployment.toml");

        string memory chain = vm.envString("CHAIN");
        string memory baseTokenTicker = vm.envString("BASE_TOKEN_TICKER");

        bytes memory data = vm.parseToml(toml, string.concat("$.", chain, ".", baseTokenTicker));

        LicredityDeploymentConfig memory deployment = abi.decode(data, (LicredityDeploymentConfig));

        // Load deployment settings
        console.log("Deploying to chain", chain, "for", baseTokenTicker);

        // Load deployment parameters
        string memory name = string.concat(deployment.debtTokenNamePrefix, " ", baseTokenTicker);
        string memory symbol = string.concat(deployment.debtTokenSymbolPrefix, baseTokenTicker);

        console.log("Base Token Address:", deployment.baseToken);
        console.log("Pool Manager Address:", deployment.poolManager);
        console.log("Interest Sensitivity:", deployment.interestSensitivity);
        console.log("Governor Address:", deployment.governor);
        console.log("Token Name:", name);
        console.log("Token Symbol:", symbol);

        bytes32 salt = deployment.salt;
        console.log("Salt:");
        console.logBytes32(salt);

        vm.startBroadcast();
        Licredity licredity = new Licredity{salt: salt}(
            deployment.baseToken,
            deployment.interestSensitivity,
            deployment.poolManager,
            deployment.governor,
            name,
            symbol
        );
        vm.stopBroadcast();

        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("Licredity deployed at:", address(licredity));
    }
}
