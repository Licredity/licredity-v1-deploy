//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.26;

import "@forge-std/Script.sol";
import "@forge-std/console.sol";
import {ChainlinkOracle} from "@licredity-v1-oracle/ChainlinkOracle.sol";
import {OracleDeploymentConfig} from "./TomlConfig.sol";

contract DeployOracleScript is Script {
    function run() external {
        string memory toml = vm.readFile("./oracle_deployment.toml");

        string memory chain = vm.envString("CHAIN");
        string memory baseTokenTicker = vm.envString("BASE_TOKEN_TICKER");

        bytes memory data = vm.parseToml(toml, string.concat("$.", chain, ".", baseTokenTicker));

        OracleDeploymentConfig memory deployment = abi.decode(data, (OracleDeploymentConfig));

        // Load deployment settings
        console.log("Deploying to chain", chain, "for", baseTokenTicker);
        console.log("Licredity Address:", deployment.licredity);
        console.log("Governor Address:", deployment.governor);

        vm.startBroadcast();
        ChainlinkOracle oracle = new ChainlinkOracle(deployment.licredity, deployment.governor);
        vm.stopBroadcast();

        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("Oracle deployed at:", address(oracle));
    }
}
