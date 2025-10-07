// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {PoolKey} from "@uniswap-v4-core/types/PoolKey.sol";
import {UniswapV4Actions} from "./UniswapV4Actions.sol";
import {ActionConstants} from "@licredity-v1-periphery/libraries/ActionConstants.sol";

struct PositionPlan {
    bytes actions;
    bytes[] params;
}

using PositionPlanner for PositionPlan global;

library PositionPlanner {
    function init() internal pure returns (PositionPlan memory plan) {
        return PositionPlan({actions: bytes(""), params: new bytes[](0)});
    }

    function add(PositionPlan memory plan, uint256 action, bytes memory param)
        internal
        pure
        returns (PositionPlan memory)
    {
        bytes memory actions = new bytes(plan.params.length + 1);
        bytes[] memory params = new bytes[](plan.params.length + 1);

        for (uint256 i; i < params.length - 1; i++) {
            // Copy from plan.
            params[i] = plan.params[i];
            actions[i] = plan.actions[i];
        }
        params[params.length - 1] = param;
        actions[params.length - 1] = bytes1(uint8(action));

        plan.actions = actions;
        plan.params = params;

        return plan;
    }

    function finalizeModifyLiquidityWithTake(PositionPlan memory plan, PoolKey memory poolKey, address takeRecipient)
        internal
        pure
        returns (bytes memory)
    {
        plan.add(UniswapV4Actions.TAKE, abi.encode(poolKey.currency0, takeRecipient, ActionConstants.OPEN_DELTA));
        plan.add(UniswapV4Actions.TAKE, abi.encode(poolKey.currency1, takeRecipient, ActionConstants.OPEN_DELTA));
        return plan.encode();
    }

    function finalizeModifyLiquidityWithTakePair(
        PositionPlan memory plan,
        PoolKey memory poolKey,
        address takeRecipient
    ) internal pure returns (bytes memory) {
        plan.add(UniswapV4Actions.TAKE_PAIR, abi.encode(poolKey.currency0, poolKey.currency1, takeRecipient));
        return plan.encode();
    }

    function encode(PositionPlan memory plan) internal pure returns (bytes memory) {
        return abi.encode(plan.actions, plan.params);
    }
}
