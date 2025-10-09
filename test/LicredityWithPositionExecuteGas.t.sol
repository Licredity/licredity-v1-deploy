//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.26;

import {Deployer} from "./Deployer.sol";
import {UniswapV4Actions} from "./utils/UniswapV4Actions.sol";
import {Planner, Plan} from "./utils/Planner.sol";
import {SwapPlanner, SwapPlan} from "./utils/SwapPlanner.sol";
import {PositionPlanner, PositionPlan} from "./utils/PositionPlanner.sol";
import {IUSDC} from "./interfaces/IUSDC.sol";
import {Fungible} from "@licredity-v1-core/types/Fungible.sol";
import {NonFungibleMock} from "@licredity-v1-core/test/NonFungibleMock.sol";
import {PoolKey} from "@uniswap-v4-core/types/PoolKey.sol";
import {Currency} from "@uniswap-v4-core/types/Currency.sol";
import {IHooks} from "@uniswap-v4-core/interfaces/IHooks.sol";
import {TickMath} from "@uniswap-v4-core/libraries/TickMath.sol";
import {IPoolManager} from "@uniswap-v4-core/interfaces/IPoolManager.sol";
import {PositionManager} from "@licredity-v1-periphery/PositionManager.sol";
import {Actions, ActionsData} from "@licredity-v1-periphery/types/Actions.sol";
import {ActionConstants} from "@licredity-v1-periphery/libraries/ActionConstants.sol";
import {IAllowanceTransfer} from "@licredity-v1-periphery/interfaces/external/IAllowanceTransfer.sol";
import {AggregatorV3Interface} from "@licredity-v1-oracle/interfaces/external/AggregatorV3Interface.sol";

contract LicredityWithUniswapExecuteGas is Deployer {
    PoolKey internal poolKey;
    PositionManager internal manager;
    NonFungibleMock internal nonFungibleMock;

    address internal uniswapV4PositionManager;
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

        poolKey = PoolKey(
            Currency.wrap(address(0)), Currency.wrap(address(licredity)), FEE, TICK_SPACING, IHooks(address(licredity))
        );

        // Deploy Licredity Position Manager
        manager = new PositionManager(address(this), poolManager, uniswapV4PositionManager, permit2);
        manager.updateLicredityMarketWhitelist(address(licredity), true);
        manager.updateTokenPermit2(
            address(licredity), address(uniswapV4PositionManager), type(uint160).max, type(uint48).max
        );

        // Configure Licredity Oracle
        deployAndSetLicredityOracle(address(licredity), address(this));
        oracle.setFungibleConfig(
            Fungible.wrap(USDC),
            0.05e6,
            AggregatorV3Interface(address(0x986b5E1e1755e3C2440e960477f25201B0a8bbD4)),
            AggregatorV3Interface(address(0))
        );
        oracle.setFungibleConfig(
            Fungible.wrap(address(0)), 0.01e6, AggregatorV3Interface(address(0)), AggregatorV3Interface(address(0))
        );
        oracle.initializeUniswapV4Module(address(uniswapV4PositionManager));
        oracle.setUniswapV4Pool(poolKey.toId(), true);
        // Config USDC minter for test
        vm.startPrank(address(0xE982615d461DD5cD06575BbeA87624fda4e3de17));
        IUSDC(USDC).configureMinter(address(this), type(uint256).max);
        vm.stopPrank();

        // Deploy NonFungibleMock
        nonFungibleMock = new NonFungibleMock();

        _deadline = block.timestamp + 1;
    }

    function test_initializeLiquidity() public {
        uint256 tokenId = manager.mint(licredity);

        PositionPlan memory positionPlan = PositionPlanner.init();
        positionPlan.add(
            UniswapV4Actions.MINT_POSITION,
            abi.encode(
                poolKey,
                int24(-2),
                int24(2),
                uint256(10000.5 ether),
                uint128(1 ether),
                uint128(1 ether),
                ActionConstants.MSG_SENDER,
                bytes("")
            )
        );
        positionPlan.add(UniswapV4Actions.SETTLE_PAIR, abi.encode(poolKey.currency0, poolKey.currency1));
        positionPlan.add(UniswapV4Actions.SWEEP, abi.encode(address(0), address(this)));
        bytes memory positionManagerCalldata = positionPlan.encode();

        Plan memory planner = Planner.init(tokenId);
        planner.add(Actions.DEPOSIT_FUNGIBLE, abi.encode(true, address(0), 2.1 ether));
        planner.add(Actions.INCREASE_DEBT_AMOUNT, abi.encode(ActionConstants.ADDRESS_THIS, 1 ether));
        // withdraw -> call position manager -> deposit
        planner.add(Actions.UNISWAP_V4_POSITION_MANAGER_CALL, abi.encode(1 ether, positionManagerCalldata));
        planner.add(Actions.DEPOSIT_NON_FUNGIBLE, abi.encode(false, address(uniswapV4PositionManager), 1)); // if tokenId = 0, nextId - 1
        ActionsData[] memory calls = planner.finalize();

        manager.execute{value: 3.1 ether}(calls, _deadline);
        vm.snapshotGasLastCall("Initialize Liquidity and deposit");
    }

    function test_swap() public {
        test_initializeLiquidity();

        uint256 tokenId = manager.mint(licredity);

        SwapPlan memory swapPlan = SwapPlanner.init();

        IPoolManager.SwapParams memory swapParam = IPoolManager.SwapParams({
            zeroForOne: false,
            amountSpecified: int256(-0.2 ether),
            sqrtPriceLimitX96: TickMath.getSqrtPriceAtTick(3)
        });
        swapPlan.add(Actions.UNISWAP_V4_SWAP, abi.encode(poolKey, swapParam, bytes("")));
        bytes memory swapCallData = swapPlan.finalizeSwap(poolKey.currency1, poolKey.currency0, address(this), false);

        Plan memory planner = Planner.init(tokenId);
        planner.add(Actions.DEPOSIT_FUNGIBLE, abi.encode(true, address(0), 0.5 ether));
        planner.add(Actions.INCREASE_DEBT_AMOUNT, abi.encode(ActionConstants.ADDRESS_THIS, 0.2 ether));
        planner.add(Actions.UNISWAP_V4_POOL_MANAGER_CALL, swapCallData);

        ActionsData[] memory calls = planner.finalize();
        manager.execute{value: 0.5 ether}(calls, _deadline);
        vm.snapshotGasLastCall("Swap 0.2 dETH to ETH");
    }

    receive() external payable {}
}
