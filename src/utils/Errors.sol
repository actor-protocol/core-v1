// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

error Unauthorized();
error ExecutionPaused();

error InvalidScenarioId();

error InvalidActorAddress();
error InvalidInputTokenAddress();
error InvalidInputAmount();

error InvalidScenarioExecutor();
error InvalidScenarioFinalOutput();

error InvalidSource(address value);
error InvalidActionExecutor(address value);

error SourceValidationError(address value);
error ActionExecutionError(address value);
