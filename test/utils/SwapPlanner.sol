// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Actions} from "@licredity-v1-periphery/types/Actions.sol";
import {ActionConstants} from "@licredity-v1-periphery/libraries/ActionConstants.sol";
import {PoolKey} from "@uniswap-v4-core/types/PoolKey.sol";
import {Currency} from "@uniswap-v4-core/types/Currency.sol";
import {IPoolManager} from "@uniswap-v4-core/interfaces/IPoolManager.sol";

struct SwapPlan {
    bytes actions;
    bytes[] params;
}

using SwapPlanner for SwapPlan global;

library SwapPlanner {
    function init() internal pure returns (SwapPlan memory plan) {
        return SwapPlan({actions: bytes(""), params: new bytes[](0)});
    }

    function add(SwapPlan memory plan, uint256 action, bytes memory param) internal pure returns (SwapPlan memory) {
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

    function addSwap(SwapPlan memory plan, PoolKey memory key, IPoolManager.SwapParams memory params)
        internal
        pure
        returns (SwapPlan memory)
    {
        plan.add(Actions.UNISWAP_V4_SWAP, abi.encode(key, params, bytes("")));

        return plan;
    }

    function encode(SwapPlan memory plan) internal pure returns (bytes memory) {
        return abi.encode(plan.actions, plan.params);
    }

    function addSwap(
        SwapPlan memory plan,
        Currency inputCurrency,
        Currency outputCurrency,
        address takeRecipient,
        bool payIsUser
    ) internal pure returns (SwapPlan memory) {
        plan = plan.add(Actions.UNISWAP_V4_SETTLE, abi.encode(inputCurrency, ActionConstants.OPEN_DELTA, payIsUser));
        plan = plan.add(Actions.UNISWAP_V4_TAKE, abi.encode(outputCurrency, takeRecipient, ActionConstants.OPEN_DELTA));

        return plan;
    }

    function finalizeSwap(
        SwapPlan memory plan,
        Currency inputCurrency,
        Currency outputCurrency,
        address takeRecipient,
        bool payIsUser
    ) internal pure returns (bytes memory) {
        plan = plan.add(Actions.UNISWAP_V4_SETTLE, abi.encode(inputCurrency, ActionConstants.OPEN_DELTA, payIsUser));
        plan = plan.add(Actions.UNISWAP_V4_TAKE, abi.encode(outputCurrency, takeRecipient, ActionConstants.OPEN_DELTA));

        return plan.encode();
    }
}
