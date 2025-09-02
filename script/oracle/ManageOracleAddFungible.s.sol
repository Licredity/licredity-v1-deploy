//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.26;

import "@forge-std/Script.sol";
import "@forge-std/console.sol";
import {OracleFungibleConfig} from "../TomlConfig.sol";
import {AggregatorV3Interface} from "@licredity-v1-oracle/interfaces/external/AggregatorV3Interface.sol";
import {IChainlinkOracle} from "@licredity-v1-oracle/interfaces/IChainlinkOracle.sol";
import {Fungible} from "@licredity-v1-core/types/Fungible.sol";

contract ManageOracleAddFungible is Script {
    function run() external {
        string memory chain = vm.envString("CHAIN");
        string memory baseTokenTicker = vm.envString("BASE_TOKEN_TICKER");

        string memory toml = vm.readFile(string.concat("oralce_configs/", chain, "_", baseTokenTicker, ".toml"));
        bytes memory data = vm.parseToml(toml, string.concat("$.oracle_address"));

        address oracleAddress = abi.decode(data, (address));
        IChainlinkOracle oracle = IChainlinkOracle(oracleAddress);
        console.log("Oracle Address:", oracleAddress);

        string memory oracleTokenTicker = vm.envString("ORACLE_TOKEN_TICKER");
        data = vm.parseToml(toml, string.concat("$.", oracleTokenTicker));
        OracleFungibleConfig memory config = abi.decode(data, (OracleFungibleConfig));

        console.log("Adding Oracle Config for", oracleTokenTicker);
        console.log("Fungible Address:", config.fungible);
        console.log("Base Feed:", config.baseFeed);
        console.log("Quote Feed:", config.quoteFeed);
        console.log("MRR (in pips):", config.mrrPips);

        Fungible fungible = Fungible.wrap(config.fungible);

        vm.startBroadcast();
        oracle.setFungibleConfig(
            fungible, config.mrrPips, AggregatorV3Interface(config.baseFeed), AggregatorV3Interface(config.quoteFeed)
        );
        vm.stopBroadcast();
        
        Fungible[] memory fungibles = new Fungible[](1);
        fungibles[0] = fungible;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1 * 10 ** fungible.decimals();

        (uint256 value, ) = oracle.quoteFungibles(fungibles, amounts);
        console.log("1", oracleTokenTicker, "=", value);
    }
}
