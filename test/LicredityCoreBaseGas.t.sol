//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.26;

import {IERC20} from "@forge-std/interfaces/IERC20.sol";
import {Deployer} from "./Deployer.sol";
import {IUSDC} from "./interfaces/IUSDC.sol";
import {ChainInfo} from "@licredity-v1-core/libraries/ChainInfo.sol";
import {Fungible} from "@licredity-v1-core/types/Fungible.sol";
import {NonFungible} from "@licredity-v1-core/types/NonFungible.sol";
import {BaseERC20Mock} from "@licredity-v1-core/test/BaseERC20Mock.sol";
import {NonFungibleMock} from "@licredity-v1-core/test/NonFungibleMock.sol";
import {AggregatorV3Interface} from "@licredity-v1-oracle/interfaces/external/AggregatorV3Interface.sol";
import {IPoolManager} from "@uniswap-v4-core/interfaces/IPoolManager.sol";

contract LicredityCoreBaseGas is Deployer {
    NonFungibleMock public nonFungibleMock;
    
    function setUp() public {
        vm.createSelectFork("ETH", 23470300);

        IPoolManager poolManager = deployUniswapV4Core(address(this), bytes32(uint256(1)));
        deployLicredity(address(0), 1, address(poolManager), address(this), "Debt ETH", "DETH");
        deployAndSetLicredityOracle(address(licredity), address(this));
        nonFungibleMock = new NonFungibleMock();

        oracle.setFungibleConfig(
            Fungible.wrap(USDC),
            0.05e6,
            AggregatorV3Interface(address(0x986b5E1e1755e3C2440e960477f25201B0a8bbD4)),
            AggregatorV3Interface(address(0))
        );

        vm.startPrank(address(0xE982615d461DD5cD06575BbeA87624fda4e3de17));
        IUSDC(USDC).configureMinter(address(this), type(uint256).max);
        vm.stopPrank();
    }

    function test_openPosition() public {
        vm.startSnapshotGas("First open position");
        licredity.openPosition();
        vm.stopSnapshotGas();

        vm.startSnapshotGas("normal open position");
        licredity.openPosition();
        vm.stopSnapshotGas();
    }

    function test_closePosition() public {
        uint256 positionId = licredity.openPosition();

        vm.startSnapshotGas("Close position");
        licredity.closePosition(positionId);
        vm.stopSnapshotGas();
    }

    function test_stageFungible() public {
        BaseERC20Mock token = _newAsset(18);

        vm.startSnapshotGas("Stage fungible With zero native balance");
        licredity.stageFungible(ChainInfo.NATIVE_FUNGIBLE);
        vm.stopSnapshotGas();

        vm.deal(address(licredity), 1 ether);
        vm.startSnapshotGas("Stage fungible With non-zero native balance");
        licredity.stageFungible(ChainInfo.NATIVE_FUNGIBLE);
        vm.stopSnapshotGas();

        vm.startSnapshotGas("Stage fungible With zero token balance");
        licredity.stageFungible(Fungible.wrap(address(token)));
        vm.stopSnapshotGas();

        token.mint(address(licredity), 1e18);

        vm.startSnapshotGas("Stage fungible With non-zero token balance");
        licredity.stageFungible(Fungible.wrap(address(token)));
        vm.stopSnapshotGas();

        vm.startSnapshotGas("Stage fungible With non-zero token balance again");
        licredity.stageFungible(Fungible.wrap(address(token)));
        vm.stopSnapshotGas();
    }

    function test_depositFungible() public {
        uint256 positionId = licredity.openPosition();

        vm.startSnapshotGas("Deposit ETH without stage");
        licredity.depositFungible{value: 1 ether}(positionId);
        vm.stopSnapshotGas();

        vm.startSnapshotGas("Deposit ETH without stage again");
        licredity.depositFungible{value: 1 ether}(positionId);
        vm.stopSnapshotGas();

        vm.startSnapshotGas("Deposit ETH with stage");
        licredity.stageFungible(ChainInfo.NATIVE_FUNGIBLE);
        licredity.depositFungible{value: 1 ether}(positionId);
        vm.stopSnapshotGas();

        IUSDC(USDC).mint(address(this), 10000e6);

        vm.startSnapshotGas("Deposit USDC from zero balance");
        licredity.stageFungible(Fungible.wrap(USDC));
        IERC20(USDC).transfer(address(licredity), 1000e6);
        licredity.depositFungible(positionId);
        vm.stopSnapshotGas();

        vm.startSnapshotGas("Deposit USDC again");
        licredity.stageFungible(Fungible.wrap(USDC));
        IERC20(USDC).transfer(address(licredity), 1000e6);
        licredity.depositFungible(positionId);
        vm.stopSnapshotGas();

        uint256 newPositionId = licredity.openPosition();
        vm.startSnapshotGas("Deposit USDC to new position");
        licredity.stageFungible(Fungible.wrap(USDC));
        IERC20(USDC).transfer(address(licredity), 1000e6);
        licredity.depositFungible(newPositionId);
        vm.stopSnapshotGas();
    }

    function getMockFungible(uint256 tokenId) public view returns (NonFungible nft) {
        address nonFungibleMockAddress = address(nonFungibleMock);
        assembly ("memory-safe") {
            nft := or(shl(96, nonFungibleMockAddress), tokenId)
        }
    }

    function test_depositNonFungible() public {
        nonFungibleMock.mint(address(this), 1);
        uint256 positionId = licredity.openPosition();

        vm.startSnapshotGas("Deposit non-fungible with stage");
        licredity.stageNonFungible(getMockFungible(1));
        nonFungibleMock.transferFrom(address(this), address(licredity), 1);
        licredity.depositNonFungible(positionId);
        vm.stopSnapshotGas();

        nonFungibleMock.mint(address(this), 2);
        vm.startSnapshotGas("Deposit non-fungible with stage again");
        licredity.stageNonFungible(getMockFungible(2));
        nonFungibleMock.transferFrom(address(this), address(licredity), 2);
        licredity.depositNonFungible(positionId);
        vm.stopSnapshotGas();
    }
}
