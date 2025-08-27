//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.26;

struct LicredityDeploymentConfig {
    address baseToken;
    string baseTokenTicker;
    string debtTokenNamePrefix;
    string debtTokenSymbolPrefix;
    address governor;
    uint256 interestSensitivity;
    address poolManager;
    bytes32 salt;
}

struct OracleDeploymentConfig {
    address governor;
    address licredity;
}
