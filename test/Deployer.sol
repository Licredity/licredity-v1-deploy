//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.26;

import {Test} from "@forge-std/Test.sol";
import {Licredity} from "@licredity-v1-core/Licredity.sol";
import {BaseERC20Mock} from "@licredity-v1-core/test/BaseERC20Mock.sol";
import {ChainlinkOracle} from "@licredity-v1-oracle/ChainlinkOracle.sol";
import {IPoolManager} from "@uniswap-v4-core/interfaces/IPoolManager.sol";

contract Deployer is Test {
    address constant PERMIT2_ADDRESS = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    Licredity public licredity;
    ChainlinkOracle public oracle;

    function _newAsset(uint8 decimals) internal returns (BaseERC20Mock) {
        return new BaseERC20Mock("Token", "T", decimals);
    }

    function deployUniswapV4Core(address initialOwner, bytes32 salt) public returns (IPoolManager poolManager) {
        bytes memory args = abi.encode(initialOwner);
        bytes memory bytecode = vm.readFileBinary("test/bin/v4PoolManager.bytecode");
        bytes memory initcode = abi.encodePacked(bytecode, args);

        assembly {
            poolManager := create2(0, add(initcode, 0x20), mload(initcode), salt)
        }

        vm.label(address(poolManager), "UniswapV4PoolManager");
    }

    function deployUniswapV4PositionManager(
        address poolManager,
        address permit2,
        uint256 unsubscribeGasLimit,
        address positionDescriptor_,
        address wrappedNative,
        bytes memory salt
    ) internal returns (address manager) {
        bytes memory args = abi.encode(poolManager, permit2, unsubscribeGasLimit, positionDescriptor_, wrappedNative);
        bytes memory bytecode = vm.readFileBinary("test/bin/v4PositionManager.bytecode");
        bytes memory initcode = abi.encodePacked(bytecode, args);
        assembly {
            manager := create2(0, add(initcode, 0x20), mload(initcode), salt)
        }

        vm.label(address(manager), "UniswapV4PositionManager");
    }

    function deployPermit2() public returns (address) {
        bytes memory bytecode = vm.readFileBinary("test/bin/permit2.bytecode");

        vm.etch(PERMIT2_ADDRESS, bytecode);
        return PERMIT2_ADDRESS;
    }

    function deployLicredity(
        address baseToken,
        uint256 interestSensitivity,
        address poolManager,
        address governor,
        string memory name,
        string memory symbol
    ) public {
        address payable mockLicredity = payable(address(0xFb46d30c9B3ACc61d714D167179748FD01E09aC0));
        vm.label(mockLicredity, "Licredity");

        bytes memory args = abi.encode(baseToken, interestSensitivity, poolManager, governor, name, symbol);
        deployCodeTo("Licredity.sol", args, mockLicredity);

        licredity = Licredity(mockLicredity);
    }

    function deployAndSetLicredityOracle(address licredityAddress, address governor) public {
        oracle = new ChainlinkOracle(licredityAddress, governor);
        licredity.setOracle(address(oracle));
    }
}
