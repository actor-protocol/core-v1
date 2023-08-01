// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {IExecutor, ExecutorInputData, ExecutorCall} from "src/interfaces/IExecutor.sol";

import {IERC20} from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract TransferExecutor is IExecutor {
    using SafeERC20 for IERC20;

    function execute(ExecutorCall calldata call) external returns (ExecutorInputData memory) {
        IERC20 token = IERC20(call.input_data.input_token);
        address target = abi.decode(call.request, (address));

        token.safeTransfer(target, call.input_data.amount);

        return ExecutorInputData({input_token: address(0), amount: 0});
    }
}
