//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.26;

import "@forge-std/Script.sol";
import "@forge-std/console.sol";
import {Licredity as TargetHook} from "@licredity-v1-core/Licredity.sol";
import {LicredityDeploymentConfig} from "./TomlConfig.sol";

contract PrintInitCodeHash is Script {
    function run() public view {
        string memory toml = vm.readFile("./deployment.toml");

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

        bytes memory constructorArguments = abi.encode(
            deployment.baseToken,
            deployment.interestSensitivity,
            deployment.poolManager,
            deployment.governor,
            name,
            symbol
        );

        // Print Init Code Hash
        bytes memory creationCodeWithConstructorArguments =
            abi.encodePacked(type(TargetHook).creationCode, constructorArguments);
        console.log("Init Code Hash:");
        console.logBytes32(keccak256(creationCodeWithConstructorArguments));
    }
}
