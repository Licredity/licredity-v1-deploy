//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.26;

interface IUSDC {
    function configureMinter(address minter, uint256 minterAllowedAmount) external;
    function mint(address to, uint256 amount) external;
}
