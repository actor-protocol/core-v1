// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

struct ExecutorInputData {
    address input_token;
    uint256 amount;
}

struct ExecutorCall {
    ExecutorInputData input_data;
    bytes request;
}

interface IExecutor {
    function execute(ExecutorCall calldata) external returns (ExecutorInputData memory);
}
