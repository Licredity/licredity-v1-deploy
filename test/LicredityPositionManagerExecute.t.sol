//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.26;

import {Deployer} from "./Deployer.sol";
import {Plan, Planner} from "./utils/Planner.sol";
import {Fungible} from "@licredity-v1-core/types/Fungible.sol";
import {IPoolManager} from "@uniswap-v4-core/interfaces/IPoolManager.sol";
import {ILicredity} from "@licredity-v1-core/interfaces/ILicredity.sol";
import {AggregatorV3Interface} from "@licredity-v1-oracle/interfaces/external/AggregatorV3Interface.sol";
import {PositionManager} from "@licredity-v1-periphery/PositionManager.sol";
import {Actions, ActionsData} from "@licredity-v1-periphery/types/Actions.sol";
import {ActionConstants} from "@licredity-v1-periphery/libraries/ActionConstants.sol";
import {IAllowanceTransfer} from "@licredity-v1-periphery/interfaces/external/IAllowanceTransfer.sol";
import {NonFungibleMock} from "@licredity-v1-core/test/NonFungibleMock.sol";
import {IUSDC} from "./interfaces/IUSDC.sol";
import {IERC20} from "@forge-std/interfaces/IERC20.sol";

contract LicredityPositionManagerExecuteGas is Deployer {
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

        oracle.setFungibleConfig(
            Fungible.wrap(address(0)), 0.05e6, AggregatorV3Interface(address(0)), AggregatorV3Interface(address(0))
        );

        // Config USDC minter for test
        vm.startPrank(address(0xE982615d461DD5cD06575BbeA87624fda4e3de17));
        IUSDC(USDC).configureMinter(address(this), type(uint256).max);
        vm.stopPrank();

        nonFungibleMock = new NonFungibleMock();

        _deadline = block.timestamp + 1;
    }

    function test_depositFungible_native() public {
        uint256 tokenId = manager.mint(licredity);

        Plan memory planner = Planner.init(tokenId);

        planner.add(Actions.DEPOSIT_FUNGIBLE, abi.encode(true, address(0), 1 ether));
        ActionsData[] memory calls = planner.finalize();

        manager.execute{value: 1 ether}(calls, _deadline);
        vm.snapshotGasLastCall("Deposit ETH");

        manager.execute{value: 1 ether}(calls, _deadline);
        vm.snapshotGasLastCall("Deposit ETH Again");
    }

    function test_depositFungible_native_multi() public {
        uint256 tokenId = manager.mint(licredity);

        Plan memory planner = Planner.init(tokenId);

        planner.add(Actions.DEPOSIT_FUNGIBLE, abi.encode(true, address(0), 1 ether));
        planner.add(Actions.DEPOSIT_FUNGIBLE, abi.encode(true, address(0), 1 ether));
        ActionsData[] memory calls = planner.finalize();

        manager.execute{value: 2 ether}(calls, _deadline);
        vm.snapshotGasLastCall("Deposit ETH Twice");
    }

    function test_depositFungible_USDC() public {
        IUSDC(USDC).mint(address(this), 10000e6);
        IERC20(USDC).approve(address(manager), type(uint256).max);

        uint256 tokenId = manager.mint(licredity);

        Plan memory planner = Planner.init(tokenId);

        planner.add(Actions.DEPOSIT_FUNGIBLE, abi.encode(true, USDC, 1000e6));
        ActionsData[] memory calls = planner.finalize();

        manager.execute(calls, _deadline);
        vm.snapshotGasLastCall("Deposit USDC from zero balance");

        manager.execute(calls, _deadline);
        vm.snapshotGasLastCall("Deposit USDC Again");
    }

    function test_depositFungible_USDC_multi() public {
        IUSDC(USDC).mint(address(this), 10000e6);
        IERC20(USDC).approve(address(manager), type(uint256).max);

        uint256 tokenId = manager.mint(licredity);

        Plan memory planner = Planner.init(tokenId);

        planner.add(Actions.DEPOSIT_FUNGIBLE, abi.encode(true, USDC, 1000e6));
        planner.add(Actions.DEPOSIT_FUNGIBLE, abi.encode(true, USDC, 1000e6));
        ActionsData[] memory calls = planner.finalize();

        manager.execute(calls, _deadline);
        vm.snapshotGasLastCall("Deposit USDC Twice");
    }

    function test_depositNonFungible() public {
        uint256 positionId = manager.mint(licredity);

        nonFungibleMock.mint(address(this), 1);
        nonFungibleMock.approve(address(manager), 1);

        Plan memory planner = Planner.init(positionId);

        planner.add(Actions.DEPOSIT_NON_FUNGIBLE, abi.encode(true, address(nonFungibleMock), 1));
        ActionsData[] memory calls = planner.finalize();

        manager.execute(calls, _deadline);
        vm.snapshotGasLastCall("Deposit non-fungible");
    }

    function test_depositNonFungible_multi() public {
        uint256 positionId = manager.mint(licredity);

        nonFungibleMock.mint(address(this), 1);
        nonFungibleMock.mint(address(this), 2);
        nonFungibleMock.mint(address(this), 3);
        nonFungibleMock.setApprovalForAll(address(manager), true);

        Plan memory planner = Planner.init(positionId);

        planner.add(Actions.DEPOSIT_NON_FUNGIBLE, abi.encode(true, address(nonFungibleMock), 1));
        planner.add(Actions.DEPOSIT_NON_FUNGIBLE, abi.encode(true, address(nonFungibleMock), 2));
        planner.add(Actions.DEPOSIT_NON_FUNGIBLE, abi.encode(true, address(nonFungibleMock), 3));
        ActionsData[] memory calls = planner.finalize();

        manager.execute(calls, _deadline);
        vm.snapshotGasLastCall("Deposit non-fungible thrice");
    }

    function test_withdrawFungible_native() public {
        uint256 tokenId = manager.mint(licredity);

        manager.depositFungible{value: 1 ether}(tokenId, address(0), 1 ether);

        Plan memory planner = Planner.init(tokenId);

        planner.add(Actions.WITHDRAW_FUNGIBLE, abi.encode(ActionConstants.MSG_SENDER, address(0), 0.5 ether));
        ActionsData[] memory calls = planner.finalize();

        manager.execute(calls, _deadline);
        vm.snapshotGasLastCall("Withdraw ETH");
    }

    function test_withdrawFungible_native_multi() public {
        uint256 tokenId = manager.mint(licredity);

        manager.depositFungible{value: 2 ether}(tokenId, address(0), 2 ether);

        Plan memory planner = Planner.init(tokenId);

        planner.add(Actions.WITHDRAW_FUNGIBLE, abi.encode(ActionConstants.MSG_SENDER, address(0), 0.5 ether));
        planner.add(Actions.WITHDRAW_FUNGIBLE, abi.encode(ActionConstants.MSG_SENDER, address(0), 0.5 ether));
        ActionsData[] memory calls = planner.finalize();

        manager.execute(calls, _deadline);
        vm.snapshotGasLastCall("Withdraw ETH Twice");
    }

    function test_withdrawFungible_USDC() public {
        uint256 tokenId = manager.mint(licredity);

        IUSDC(USDC).mint(address(this), 10000e6);
        IERC20(USDC).approve(address(manager), type(uint256).max);

        manager.depositFungible(tokenId, USDC, 1000e6);

        Plan memory planner = Planner.init(tokenId);

        planner.add(Actions.WITHDRAW_FUNGIBLE, abi.encode(ActionConstants.MSG_SENDER, USDC, 500e6));
        ActionsData[] memory calls = planner.finalize();

        manager.execute(calls, _deadline);
        vm.snapshotGasLastCall("Withdraw USDC");
    }

    function test_withdrawFungible_USDC_multi() public {
        uint256 tokenId = manager.mint(licredity);

        IUSDC(USDC).mint(address(this), 10000e6);
        IERC20(USDC).approve(address(manager), type(uint256).max);

        manager.depositFungible(tokenId, USDC, 1000e6);

        Plan memory planner = Planner.init(tokenId);

        planner.add(Actions.WITHDRAW_FUNGIBLE, abi.encode(ActionConstants.MSG_SENDER, USDC, 500e6));
        planner.add(Actions.WITHDRAW_FUNGIBLE, abi.encode(ActionConstants.MSG_SENDER, USDC, 500e6));
        ActionsData[] memory calls = planner.finalize();

        manager.execute(calls, _deadline);
        vm.snapshotGasLastCall("Withdraw USDC Twice");
    }

    function test_withdrawNonFungible() public {
        uint256 positionId = manager.mint(licredity);

        nonFungibleMock.mint(address(this), 1);
        nonFungibleMock.approve(address(manager), 1);

        manager.depositNonFungible(positionId, address(nonFungibleMock), 1);

        Plan memory planner = Planner.init(positionId);

        planner.add(Actions.WITHDRAW_NON_FUNGIBLE, abi.encode(address(0xdeadbeef), address(nonFungibleMock), 1));
        ActionsData[] memory calls = planner.finalize();

        manager.execute(calls, _deadline);
        vm.snapshotGasLastCall("Withdraw non-fungible");
    }

    function test_withdrawNonFungible_multi() public {
        uint256 positionId = manager.mint(licredity);

        nonFungibleMock.mint(address(this), 1);
        nonFungibleMock.mint(address(this), 2);
        nonFungibleMock.mint(address(this), 3);
        nonFungibleMock.setApprovalForAll(address(manager), true);

        manager.depositNonFungible(positionId, address(nonFungibleMock), 1);
        manager.depositNonFungible(positionId, address(nonFungibleMock), 2);
        manager.depositNonFungible(positionId, address(nonFungibleMock), 3);

        Plan memory planner = Planner.init(positionId);

        planner.add(Actions.WITHDRAW_NON_FUNGIBLE, abi.encode(address(0xdeadbeef), address(nonFungibleMock), 1));
        planner.add(Actions.WITHDRAW_NON_FUNGIBLE, abi.encode(address(0xdeadbeef), address(nonFungibleMock), 2));
        planner.add(Actions.WITHDRAW_NON_FUNGIBLE, abi.encode(address(0xdeadbeef), address(nonFungibleMock), 3));
        ActionsData[] memory calls = planner.finalize();

        manager.execute(calls, _deadline);
        vm.snapshotGasLastCall("Withdraw non-fungible thrice");
    }

    function test_increaseDebtAmount() public {
        uint256 tokenId = manager.mint(licredity);
        manager.depositFungible{value: 10 ether}(tokenId, address(0), 10 ether);

        Plan memory planner = Planner.init(tokenId);

        planner.add(Actions.INCREASE_DEBT_AMOUNT, abi.encode(ActionConstants.MSG_SENDER, 1 ether));
        ActionsData[] memory calls = planner.finalize();

        manager.execute(calls, _deadline);
        vm.snapshotGasLastCall("Increase debt amount");
    }

    function test_increaseDebtAmount_multi() public {
        uint256 tokenId = manager.mint(licredity);
        manager.depositFungible{value: 10 ether}(tokenId, address(0), 10 ether);

        Plan memory planner = Planner.init(tokenId);

        planner.add(Actions.INCREASE_DEBT_AMOUNT, abi.encode(ActionConstants.MSG_SENDER, 1 ether));
        planner.add(Actions.INCREASE_DEBT_AMOUNT, abi.encode(ActionConstants.MSG_SENDER, 1 ether));
        ActionsData[] memory calls = planner.finalize();

        manager.execute(calls, _deadline);
        vm.snapshotGasLastCall("Increase debt amount twice");
    }

    function test_decreaseDebtAmount_directly() public {
        uint256 tokenId = manager.mint(licredity);
        manager.depositFungible{value: 10 ether}(tokenId, address(0), 10 ether);
        Plan memory planner = Planner.init(tokenId);

        planner.add(Actions.INCREASE_DEBT_AMOUNT, abi.encode(ActionConstants.MSG_SENDER, 1 ether));
        ActionsData[] memory calls = planner.finalize();
        manager.execute(calls, _deadline);

        IERC20(address(licredity)).approve(address(manager), type(uint256).max);

        manager.decreaseDebtAmount(tokenId, 0.5 ether);
        vm.snapshotGasLastCall("Decrease debt amount Directly");
    }

    function test_decreaseDebtAmount() public {
        uint256 tokenId = manager.mint(licredity);
        manager.depositFungible{value: 10 ether}(tokenId, address(0), 10 ether);
        Plan memory planner = Planner.init(tokenId);

        planner.add(Actions.INCREASE_DEBT_AMOUNT, abi.encode(ActionConstants.MSG_SENDER, 1 ether));
        ActionsData[] memory calls = planner.finalize();
        manager.execute(calls, _deadline);

        IERC20(address(licredity)).approve(address(manager), type(uint256).max);

        planner = Planner.init(tokenId);
        planner.add(Actions.DECREASE_DEBT_AMOUNT, abi.encode(true, 0.5 ether, false));
        calls = planner.finalize();

        manager.execute(calls, _deadline);
        vm.snapshotGasLastCall("Decrease debt amount");
    }

    function test_decreaseDebtAmount_multi() public {
        uint256 tokenId = manager.mint(licredity);
        manager.depositFungible{value: 10 ether}(tokenId, address(0), 10 ether);
        Plan memory planner = Planner.init(tokenId);

        planner.add(Actions.INCREASE_DEBT_AMOUNT, abi.encode(ActionConstants.MSG_SENDER, 2 ether));
        ActionsData[] memory calls = planner.finalize();
        manager.execute(calls, _deadline);

        IERC20(address(licredity)).approve(address(manager), type(uint256).max);

        planner = Planner.init(tokenId);
        planner.add(Actions.DECREASE_DEBT_AMOUNT, abi.encode(true, 0.5 ether, false));
        planner.add(Actions.DECREASE_DEBT_AMOUNT, abi.encode(true, 0.5 ether, false));
        calls = planner.finalize();

        manager.execute(calls, _deadline);
        vm.snapshotGasLastCall("Decrease debt amount twice");
    }

    receive() external payable {}
}
