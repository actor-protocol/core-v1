// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {RegisterType} from "../enums/ERegisterType.sol";
import {Scenario, ScenarioWrapper} from "../structs/SScenario.sol";

interface ICore {
    event RegisterUpdated(RegisterType indexed t, address indexed addr, bool indexed value);
    event ExecutionStateUpdated(bool _old, bool indexed _new);

    event ScenarioAdded(address indexed, uint64 indexed);
    event ScenarioRemoved(address indexed, uint64 indexed);
    event ScenarioExecuted(address indexed, uint64 indexed);

    // Getters
    function getCounter() external view returns (uint256);

    // Management functions.
    function updateRegister(RegisterType, address, bool) external;
    function updateExecutionPauseState(bool) external;
    function getExecutionPausedState() external view returns (bool);

    // Scenario read methods.
    function getScenario(uint64) external view returns (bool, Scenario memory);
    function getScenariosByOwner(address) external view returns (ScenarioWrapper[] memory);
    function getScenariosIdsByOwner(address) external view returns (uint64[] memory);

    // Scenario write methods.
    function addScenario(Scenario calldata) external returns (uint64);
    function removeScenario(uint64) external;
    function executeScenario(address, uint64, uint8) external;
}
