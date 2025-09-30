//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.26;

import {Deployer} from "./Deployer.sol";
import {Fungible} from "@licredity-v1-core/types/Fungible.sol";
import {IPoolManager} from "@uniswap-v4-core/interfaces/IPoolManager.sol";
import {ILicredity} from "@licredity-v1-core/interfaces/ILicredity.sol";
import {AggregatorV3Interface} from "@licredity-v1-oracle/interfaces/external/AggregatorV3Interface.sol";
import {PositionManager} from "@licredity-v1-periphery/PositionManager.sol";
import {IAllowanceTransfer} from "@licredity-v1-periphery/interfaces/external/IAllowanceTransfer.sol";
import {NonFungibleMock} from "@licredity-v1-core/test/NonFungibleMock.sol";
import {IUSDC} from "./interfaces/IUSDC.sol";
import {IERC20} from "@forge-std/interfaces/IERC20.sol";

contract LicredityPositionManagerGas is Deployer {
    NonFungibleMock internal nonFungibleMock;

    address internal uniswapV4PositionManager;
    PositionManager internal manager;

    address internal constant WETH = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    uint256 internal _deadline;

    function setUp() public {
        vm.createSelectFork("ETH", 23470300);

        // Deploy Uniswap V4 Core and Licredity Core
        IPoolManager poolManager = deployUniswapV4Core(address(this), bytes32(uint256(1)));
        deployLicredity(address(0), 1, address(poolManager), address(this), "Debt ETH", "DETH");

        // Deploy Uniswap V4 Position Manager
        IAllowanceTransfer permit2 = IAllowanceTransfer(deployPermit2());
        uniswapV4PositionManager =
            deployUniswapV4PositionManager(address(poolManager), PERMIT2_ADDRESS, 200000, address(0), WETH, hex"02");

        // Deploy Licredity Position Manager
        manager = new PositionManager(address(this), poolManager, uniswapV4PositionManager, permit2);
        manager.updateLicredityMarketWhitelist(address(licredity), true);

        // Configure Licredity Oracle
        deployAndSetLicredityOracle(address(licredity), address(this));
        oracle.setFungibleConfig(
            Fungible.wrap(USDC),
            0.05e6,
            AggregatorV3Interface(address(0x986b5E1e1755e3C2440e960477f25201B0a8bbD4)),
            AggregatorV3Interface(address(0))
        );

        // Config USDC minter for test
        vm.startPrank(address(0xE982615d461DD5cD06575BbeA87624fda4e3de17));
        IUSDC(USDC).configureMinter(address(this), type(uint256).max);
        vm.stopPrank();

        nonFungibleMock = new NonFungibleMock();

        _deadline = block.timestamp + 1;
    }

    function test_mint() public {
        manager.mint(licredity);
        vm.snapshotGasLastCall("Mint First");

        manager.mint(licredity);
        vm.snapshotGasLastCall("Mint Normal");
    }

    function test_burn() public {
        uint256 tokenId = manager.mint(licredity);

        manager.burn(tokenId);
        vm.snapshotGasLastCall("Burn");

        tokenId = manager.mint(licredity);
        manager.approve(address(0xb0b), tokenId);

        vm.prank(address(0xb0b));
        manager.burn(tokenId);
        vm.snapshotGasLastCall("Burn with approve");
    }

    function test_depositFungible_native() public {
        uint256 tokenId = manager.mint(licredity);

        manager.depositFungible{value: 0.1 ether}(tokenId, address(0), 0.1 ether);
        vm.snapshotGasLastCall("Deposit ETH");

        manager.depositFungible{value: 0.1 ether}(tokenId, address(0), 0.1 ether);
        vm.snapshotGasLastCall("Deposit ETH again");
    }

    function test_depositFungible_USDC() public {
        uint256 tokenId = manager.mint(licredity);

        IUSDC(USDC).mint(address(this), 10000e6);
        IERC20(USDC).approve(address(manager), type(uint256).max);

        manager.depositFungible(tokenId, USDC, 1000e6);
        vm.snapshotGasLastCall("Deposit USDC from zero balance");

        manager.depositFungible(tokenId, USDC, 1000e6);
        vm.snapshotGasLastCall("Deposit USDC again");

        tokenId = manager.mint(licredity);
        manager.depositFungible(tokenId, USDC, 1000e6);
        vm.snapshotGasLastCall("Deposit USDC to new position");
    }

    function test_depositNonFungible() public {
        uint256 positionId = manager.mint(licredity);

        nonFungibleMock.mint(address(this), 1);
        nonFungibleMock.approve(address(manager), 1);

        manager.depositNonFungible(positionId, address(nonFungibleMock), 1);
        vm.snapshotGasLastCall("Deposit non-fungible");

        nonFungibleMock.mint(address(this), 2);
        nonFungibleMock.approve(address(manager), 2);

        manager.depositNonFungible(positionId, address(nonFungibleMock), 2);
        vm.snapshotGasLastCall("Deposit non-fungible again");
    }
}
