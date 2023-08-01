// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {ICore} from "./interfaces/ICore.sol";

import {List} from "./structs/SList.sol";
import {ListLibrary} from "./libraries/List.sol";

import {RegisterType} from "./enums/ERegisterType.sol";

import {Scenario, ScenarioWrapper} from "./structs/SScenario.sol";
import {SourceData} from "./structs/SSourceData.sol";
import {ActionData} from "./structs/SActionData.sol";

import {ISource, SourceCall} from "./interfaces/ISource.sol";
import {IExecutor, ExecutorCall, ExecutorInputData} from "./interfaces/IExecutor.sol";

import {Context} from "openzeppelin-contracts/contracts/utils/Context.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

import "./utils/Errors.sol";

contract Core is ICore, Context, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using ListLibrary for List;

    // Management address storage.
    address private s_manager;

    // Pause execution state storage.
    // [!] Only pauses execution.
    // [!] User's funds ALWAYS can be withdrawn by stopping (deleting) scenario (`removeScenario` method).
    bool private s_executionPaused;

    // Scenarios storage.
    uint64 private s_counter;
    mapping(uint64 => Scenario) private s_scenarios;
    mapping(address => List) private s_list;

    // Source register.
    mapping(address => bool) private s_sourceRegister;

    // Action register.
    mapping(address => bool) private s_actionRegister;

    // Modifiers.
    modifier onlyManager() {
        // Check if the sender of the transaction is the same as the manager address.
        if (_msgSender() != s_manager) {
            revert Unauthorized();
        }

        // Continue executing the original function where this modifier is used.
        _;
    }

    /**
     * Core contract constructor.
     */
    constructor(address _manager) {
        s_manager = _manager;
    }

    /**
     * Updates values in source and action registers.
     *
     * @param t The type of register to be updated.
     * @param addr The address of a source or action.
     * @param value The new register value for the given address.
     */
    function updateRegister(RegisterType t, address addr, bool value) external onlyManager {
        // Check if the register type is "Source".
        if (t == RegisterType.Source) {
            // Emit an event to signal that the Source register is being updated with the new value.
            emit RegisterUpdated(t, addr, value);

            // Update the value of the given address.
            s_sourceRegister[addr] = value;
            // Check if the register type is "Action".
        } else {
            // Emit an event to signal that the Action register is being updated with the new value.
            emit RegisterUpdated(t, addr, value);

            // Update the value of the given address.
            s_actionRegister[addr] = value;
        }
    }

    /**
     * Checks if the given address is registered in the Source register.
     * @return value The result boolean.
     */
    function checkSourceRegister(address addr) external view returns (bool) {
        // Return the value associated with the given address in the Source register.
        return s_sourceRegister[addr];
    }

    /**
     * Checks if the given address is registered in the Source register.
     * @return value The result boolean.
     */
    function checkActionRegister(address addr) external view returns (bool) {
        // Return the value associated with the given address in the Action register.
        return s_actionRegister[addr];
    }

    /**
     * Updates execution pause state value.
     * @param value The new execution pause value.
     */
    function updateExecutionPauseState(bool value) external onlyManager {
        // Emit an event to indicate successful change of the execution state value.
        emit ExecutionStateUpdated(s_executionPaused, value);

        // Update the execution pause state with the new value.
        s_executionPaused = value;
    }

    /**
     * Returns the current state of execution paused flag.
     * @return state Bool indicating whether the execution is currently paused or not.
     */
    function getExecutionPausedState() external view returns (bool) {
        // Return current value of the execution paused state.
        return s_executionPaused;
    }

    /**
     * Returns scenario ID counter value.
     * @return value Counter value.
     */
    function getCounter() external view returns (uint256) {
        // Return current value of the scenario ID counter.
        return s_counter;
    }

    /**
     * Retrieves information about a scenario using its ID.
     * @param id The ID of the scenario.
     * @return status The status of the operation.
     * @return scenario The data of the scenario.
     */
    function getScenario(uint64 id) external view returns (bool, Scenario memory) {
        // Check if the scenario with the given ID exists (input_amount is zero for non-existent scenarios).
        if (s_scenarios[id].input_amount == 0) {
            // If the scenario doesn't exist, return false as a status and an empty scenario object.
            return (false, s_scenarios[id]);
        }

        // If the scenario exists, return true as a status and the data of the scenario.
        return (true, s_scenarios[id]);
    }

    /**
     * Retrieves all scenarios associated with a particular address.
     * @param owner The address of the owner.
     */
    function getScenariosByOwner(address owner) external view returns (ScenarioWrapper[] memory m_scenarios) {
        // Create a new dynamic array of type Scenario to store the retrieved scenarios.
        m_scenarios = new ScenarioWrapper[](s_list[owner]._length);

        // Loop through all the scenario IDs associated with the given owner address.
        for (uint64 i = 0; i < s_list[owner]._length;) {
            // Retrieve the scenario data and store it at the current index in the dynamic array.
            m_scenarios[i] = ScenarioWrapper({id: s_list[owner]._kv[i], scenario: s_scenarios[s_list[owner]._kv[i]]});

            // Increment i using unchecked to bypass overflow checks.
            unchecked {
                i++;
            }
        }
    }

    /**
     * Retrieves the IDs of all scenarios associated with a particular owner.
     * @param owner The address of the owner.
     */
    function getScenariosIdsByOwner(address owner) external view returns (uint64[] memory m_ids) {
        // Create a new dynamic array to store the scenario IDs associated with the owner.
        m_ids = new uint64[](s_list[owner]._length);

        // Loop through all the scenario IDs associated with the given owner address.
        for (uint64 i = 0; i < s_list[owner]._length;) {
            // Store the scenario ID at the current index in the dynamic array.
            m_ids[i] = s_list[owner]._kv[i];

            // Increment i using unchecked to bypass overflow checks.
            unchecked {
                i++;
            }
        }
    }

    /**
     * Adds a new scenario.
     * @param scenario The data of the scenario to be added.
     */
    function addScenario(Scenario calldata scenario) external returns (uint64 id) {
        // Check if the actor address is valid (not equal to address(0)).
        if (scenario.actor == address(0)) {
            revert InvalidActorAddress();
        }

        // Check if the input token address is valid (not equal to address(0)).
        if (scenario.input_token == address(0)) {
            revert InvalidInputTokenAddress();
        }

        // Check if the input amount is greater than 0.
        if (scenario.input_amount == 0) {
            revert InvalidInputAmount();
        }

        // Loop through each script in the scenario.
        for (uint8 i = 0; i < scenario.scripts.length;) {
            // Loop through each source that needs verification in the current script.
            for (uint8 j = 0; j < scenario.scripts[i].sources_to_verify.length;) {
                // Get the source dat.
                SourceData calldata source = scenario.scripts[i].sources_to_verify[j];

                // Check if the source address is registered in the source register.
                if (!s_sourceRegister[source.addr]) {
                    revert InvalidSource(source.addr);
                }

                // Increment j using unchecked to bypass overflow checks.
                unchecked {
                    j++;
                }
            }

            // Loop through each action in the current script.
            for (uint8 j = 0; j < scenario.scripts[i].actions_chain.length;) {
                // Get the action dat.
                ActionData calldata action = scenario.scripts[i].actions_chain[j];

                // Check if the action executor is registered in the action register.
                if (!s_actionRegister[action.executor]) {
                    revert InvalidActionExecutor(action.executor);
                }

                // Increment j using unchecked to bypass overflow checks.
                unchecked {
                    j++;
                }
            }

            // Increment i using unchecked to bypass overflow checks.
            unchecked {
                i++;
            }
        }

        // Transfer the input tokens from the message sender to this contract.
        IERC20(scenario.input_token).safeTransferFrom(_msgSender(), address(this), scenario.input_amount);

        // Increment the scenario ID counter and assign it to the id variable.
        unchecked {
            id = ++s_counter;
        }

        // Store the scenario in the contract.
        s_scenarios[id] = scenario;

        // Insert the scenario ID into the sender's list of owned scenario.
        s_list[_msgSender()].insert(id);

        // Emit an event to indicate successful addition of the scenario.
        emit ScenarioAdded(_msgSender(), id);
    }

    /**
     * Removes a scenario.
     * @param id The ID of the scenario to be removed.
     */
    function removeScenario(uint64 id) external {
        // Check if the sender has ownership of the scenario with the provided ID.
        if (!s_list[_msgSender()].contains(id)) {
            // If the sender does not own the scenario, revert the transaction with an error.
            revert InvalidScenarioId();
        }

        // Get a reference to the storage of the scenario with the given ID.
        Scenario storage s_scenario = s_scenarios[id];

        // Transfer the input token of the scenario back to the sender.
        IERC20(s_scenario.input_token).safeTransfer(_msgSender(), s_scenario.input_amount);

        // Delete the scenario from the storage to remove it from the contract.
        delete s_scenarios[id];

        // Remove the scenario ID from the sender's list of owned scenarios.
        s_list[_msgSender()].remove(id);

        // Emit an event to indicate successful removal of the scenario.
        emit ScenarioRemoved(_msgSender(), id);
    }

    /**
     * Executes a script within the specified scenario.
     * @param owner The address of the owner.
     * @param id The ID of the scenario.
     * @param scriptIndex The index of the script within the scenario.
     */
    function executeScenario(address owner, uint64 id, uint8 scriptIndex) external nonReentrant {
        // Check if the execution is paused.
        if (s_executionPaused) {
            // Revert the transaction with an error message.
            revert ExecutionPaused();
        }

        // Check if the scenario ID is associated with the specified owner.
        if (!s_list[owner].contains(id)) {
            // Revert the transaction with an error message.
            revert InvalidScenarioId();
        }

        // Check if the executor of the scenario is the same as the one calling the function.
        if (s_scenarios[id].actor != _msgSender()) {
            // Revert the transaction with an error message.
            revert InvalidScenarioExecutor();
        }

        // Get the reference to the scenario using the provided ID.
        Scenario storage s_scenario = s_scenarios[id];

        // Loop through each source in the script's sources_to_verify array.
        for (uint8 i = 0; i < s_scenario.scripts[scriptIndex].sources_to_verify.length;) {
            // Get the reference to the source.
            SourceData storage source = s_scenario.scripts[scriptIndex].sources_to_verify[i];

            // Validate the source by calling its `validate` function and passing necessary data.
            try ISource(source.addr).validate(
                SourceCall({kind: source.kind, input: source.input, condition: source.condition})
            ) {} catch {
                // Revert the transaction with an error message if validation fails.
                revert SourceValidationError(source.addr);
            }

            // Increment i using unchecked to bypass overflow checks.
            unchecked {
                i++;
            }
        }

        // Prepare the input data for the script's execution.
        ExecutorInputData memory input_data =
            ExecutorInputData({input_token: s_scenario.input_token, amount: s_scenario.input_amount});

        // Loop through each action in the script's actions_chain array.
        for (uint8 i = 0; i < s_scenario.scripts[scriptIndex].actions_chain.length;) {
            // Get the reference to the action.
            ActionData storage s_action = s_scenario.scripts[scriptIndex].actions_chain[i];

            // Transfer the specified amount of input tokens to the action's executor.
            IERC20(input_data.input_token).safeTransfer(s_action.executor, input_data.amount);

            // Execute the action using the executor's `execute` function and passing necessary data.
            try IExecutor(s_action.executor).execute(ExecutorCall({input_data: input_data, request: s_action.input}))
            returns (ExecutorInputData memory output) {
                // Update the input_data with the returned output for the next action.
                input_data = output;
            } catch {
                // Revert the transaction with an error message if execution fails.
                revert ActionExecutionError(s_action.executor);
            }

            // Increment i using unchecked to bypass overflow checks.
            unchecked {
                i++;
            }
        }

        // Check if there are any remaining input tokens or amount after execution.
        if (input_data.input_token != address(0) || input_data.amount != 0) {
            // Revert the transaction with an error message.
            revert InvalidScenarioFinalOutput();
        }

        // Clean up the scenario and remove it from the owner's scenario list.
        delete s_scenarios[id];
        s_list[_msgSender()].remove(id);

        // Emit an event to indicate the successful execution of the scenario.
        emit ScenarioExecuted(_msgSender(), id);
    }
}
