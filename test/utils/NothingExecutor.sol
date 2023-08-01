// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {IExecutor, ExecutorInputData, ExecutorCall} from "src/interfaces/IExecutor.sol";

import {IERC20} from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract NothingExecutor is IExecutor {
    using SafeERC20 for IERC20;

    function execute(ExecutorCall calldata call) external pure returns (ExecutorInputData memory) {
        return ExecutorInputData({input_token: call.input_data.input_token, amount: call.input_data.amount});
    }
}
