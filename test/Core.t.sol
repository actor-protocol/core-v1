// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "forge-std/Test.sol";

import {IERC20} from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import {Core} from "src/Core.sol";

import {RegisterType} from "src/enums/ERegisterType.sol";
import {List} from "src/structs/SList.sol";

import {Script, Scenario, ScenarioWrapper, TriggerType} from "src/structs/SScenario.sol";
import {SourceData} from "src/structs/SSourceData.sol";
import {ActionData} from "src/structs/SActionData.sol";

import "src/utils/Errors.sol";

import {CoreLibrary} from "./utils/CoreLibrary.sol";
import {ERC20Token} from "./utils/ERC20Token.sol";
import {DexSource, SourceCall} from "./utils/DexSource.sol";
import {TransferExecutor} from "./utils/TransferExecutor.sol";
import {NothingExecutor} from "./utils/NothingExecutor.sol";

contract CoreTest is Test {
    using SafeERC20 for IERC20;
    using CoreLibrary for Core;

    IERC20 public token;

    Core public core;
    DexSource public dexsource;
    TransferExecutor public transferExecutor;
    NothingExecutor public nothingExecutor;

    // Function to set up the initial state for testing.
    function setUp() public {
        // Create a new ERC20 token for testing.
        token = new ERC20Token("Token", "TKN", 100_000_000, address(this));

        // Create instances of contract dependencies for the Core contract.
        core = new Core(address(this));
        dexsource = new DexSource();
        transferExecutor = new TransferExecutor();
        nothingExecutor = new NothingExecutor();

        // Set up the Core contract with the created dependencies.
        address[] memory sources = new address[](1);
        sources[0] = address(dexsource);

        address[] memory actions = new address[](2);
        actions[0] = address(transferExecutor);
        actions[1] = address(nothingExecutor);

        core.setUp(sources, actions);
    }

    // Function to test updating the registers.
    function testUpdateRegister() external {
        // Check if the source and action registers have the initial value of false.
        assert(!core.checkSourceRegister(address(0)));
        assert(!core.checkActionRegister(address(0)));

        // Update the source and action registers with a new value of true.
        core.updateRegister(RegisterType.Source, address(0), true);
        core.updateRegister(RegisterType.Action, address(0), true);

        // Check if the source and action registers have been updated to true.
        assert(core.checkSourceRegister(address(0)));
        assert(core.checkActionRegister(address(0)));
    }

    // Function to test updating the execution paused state.
    function testUpdateExecutionPauseState() external {
        // Update the execution paused state to true.
        core.updateExecutionPauseState(true);

        // Check if the execution paused state has been set to true.
        assert(core.getExecutionPausedState() == true);
    }

    // Function to test unauthorized update of the execution paused state.
    function testUnauthorizedupdateExecutionPauseState() external {
        // Simulate sender address being set to the address(0).
        vm.prank(address(0));
        // Expect the function call to revert with the reason "Unauthorized".
        vm.expectRevert(Unauthorized.selector);

        // Try to update the execution paused state to true.
        core.updateExecutionPauseState(true);
    }

    // Function to test getting the counter value from the Core contract (view function).
    function testGetCounter() external view {
        // Check if the counter value returned by the contract is 0.
        assert(core.getCounter() == 0);
    }

    // Function to test adding and retrieving a scenario.
    function testGetScenario() external {
        // Add an empty scenario.
        uint64 id = core.addEmptyScenario(token, address(1));

        // Get the status of the added scenario and an invalid scenario.
        (bool idStatus,) = core.getScenario(id);
        (bool invalidStatus,) = core.getScenario(id + 1);

        // Check if the status of the added scenario is true and the invalid scenario is false.
        assert(idStatus);
        assert(!invalidStatus);
    }

    // Function to test getting scenarios by owner.
    function testGetScenariosByOwner() external {
        // Add an empty scenario.
        uint64 id = core.addEmptyScenario(token, address(1));

        // Get the scenarios associated with a specific owner and an unknown owner.
        ScenarioWrapper[] memory ownerScenarios = core.getScenariosByOwner(address(1));
        ScenarioWrapper[] memory unknownScenarios = core.getScenariosByOwner(address(2));

        // Check if the number of scenarios for the owner is 1 and for the unknown owner is 0.
        assert(ownerScenarios.length == 1);
        assert(unknownScenarios.length == 0);

        // Check if the ID of the scenario for the owner matches the ID of the added scenario.
        assert(ownerScenarios[0].id == id);
    }

    // Function to test getting scenario IDs by owner.
    function testGetScenariosIdsByOwner() external {
        // Add an empty scenario.
        uint64 id = core.addEmptyScenario(token, address(1));

        // Get the scenario IDs associated with a specific owner and an unknown owner.
        uint64[] memory ownerScenarios = core.getScenariosIdsByOwner(address(1));
        uint64[] memory unknownScenarios = core.getScenariosIdsByOwner(address(2));

        // Check if the number of scenario IDs for the owner is 1 and for the unknown owner is 0.
        assert(ownerScenarios.length == 1);
        assert(unknownScenarios.length == 0);

        // Check if the scenario ID for the owner matches the ID of the added scenario.
        assert(ownerScenarios[0] == id);
    }

    // Function to test adding a scenario.
    function testAddScenario() external {
        // Set up variables for the test scenario.
        uint256 amount = 1_000_000;
        address owner = address(1);

        // Transfer tokens to the owner for testing.
        token.safeTransfer(owner, amount);

        // Simulate sender address being set to the owner.
        vm.startPrank(owner);

        // Approve the Core contract to transfer tokens on behalf of the owner.
        token.safeIncreaseAllowance(address(core), amount);

        // Create a script for the scenario.
        Script[] memory scripts = new Script[](1);
        Scenario memory scenario = Scenario({
            owner: owner,
            actor: address(this),
            input_token: address(token),
            input_amount: amount,
            scripts: scripts
        });

        // Add the scenario to the Core contract.
        core.addScenario(scenario, 0);

        // Stop the sender address simulation.
        vm.stopPrank();

        // Check if the owner's token balance is 0 (tokens transferred to Core contract).
        assert(token.balanceOf(owner) == 0);
        // Check if the Core contract's token balance is equal to the initial amount.
        assert(token.balanceOf(address(core)) == amount);
    }

    // Function to test adding a scenario with an invalid actor address.
    function testAddScenarioInvalidActor() external {
        // Create a script for the scenario with an invalid actor address (address(0)).
        Script[] memory scripts = new Script[](1);
        Scenario memory scenario = Scenario({
            owner: address(this),
            actor: address(0),
            input_token: address(token),
            input_amount: 1,
            scripts: scripts
        });

        // Expect the function call to revert with the reason "InvalidActorAddress".
        vm.expectRevert(InvalidActorAddress.selector);

        // Try to add the scenario.
        core.addScenario(scenario, 0);
    }

    // Function to test adding a scenario with an invalid input token address.
    function testAddScenarioInvalidInputTokenAddress() external {
        // Create a script for the scenario with an invalid input token address (address(0)).
        Script[] memory scripts = new Script[](1);
        Scenario memory scenario = Scenario({
            owner: address(this),
            actor: address(1),
            input_token: address(0),
            input_amount: 1,
            scripts: scripts
        });

        // Expect the function call to revert with the reason "InvalidInputTokenAddress".
        vm.expectRevert(InvalidInputTokenAddress.selector);

        // Try to add the scenario.
        core.addScenario(scenario, 0);
    }

    // Function to test adding a scenario with an invalid input amount.
    function testAddScenarioInvalidInputAmount() external {
        // Create a script for the scenario with an invalid input amount (0).
        Script[] memory scripts = new Script[](1);
        Scenario memory scenario = Scenario({
            owner: address(this),
            actor: address(1),
            input_token: address(token),
            input_amount: 0,
            scripts: scripts
        });

        // Expect the function call to revert with the reason "InvalidInputAmount".
        vm.expectRevert(InvalidInputAmount.selector);

        // Try to add the scenario.
        core.addScenario(scenario, 0);
    }

    // Function to test adding a scenario with an invalid source address.
    function testAddScenarioInvalidSource() external {
        // Create a script for the scenario with an invalid source address (address(0)).
        Script[] memory scripts = new Script[](1);
        scripts[0].sources_to_verify = new SourceData[](1);
        scripts[0].sources_to_verify[0] = SourceData({addr: address(0), kind: 0, input: "", condition: ""});

        Scenario memory scenario = Scenario({
            owner: address(this),
            actor: address(1),
            input_token: address(token),
            input_amount: 1,
            scripts: scripts
        });

        // Expect the function call to revert with the reason "InvalidSource".
        vm.expectRevert(abi.encodeWithSelector(InvalidSource.selector, address(0)));

        // Try to add the scenario.
        core.addScenario(scenario, 0);
    }

    // Function to test adding a scenario with an invalid action executor address.
    function testAddScenarioInvalidAction() external {
        // Create a script for the scenario with an invalid action executor address (address(0)).
        Script[] memory scripts = new Script[](1);
        scripts[0].actions_chain = new ActionData[](1);
        scripts[0].actions_chain[0] = ActionData({executor: address(0), input: ""});

        Scenario memory scenario = Scenario({
            owner: address(this),
            actor: address(1),
            input_token: address(token),
            input_amount: 1,
            scripts: scripts
        });

        // Expect the function call to revert with the reason "InvalidActionExecutor".
        vm.expectRevert(abi.encodeWithSelector(InvalidActionExecutor.selector, address(0)));

        // Add the scenario to the Core contract (should revert due to invalid action executor address).
        core.addScenario(scenario, 0);
    }

    // Function to test unauthorized removal of a scenario.
    function testUnauthorizedRemoveScenario() external {
        // Add an empty scenario.
        uint64 id = core.addEmptyScenario(token, address(1));
        // Expect the function call to revert with the reason "InvalidScenarioId".
        vm.expectRevert(InvalidScenarioId.selector);

        // Try to remove the scenario with an unauthorized address.
        core.removeScenario(id);
    }

    // Function to test removal of a scenario.
    function testRemoveScenario() external {
        // Add an empty scenario.
        uint64 id = core.addEmptyScenario(token, address(1));
        // Get the added scenario.
        (, Scenario memory scenario) = core.getScenario(id);

        // Simulate sender address being set to the owner.
        vm.prank(address(1));

        // Remove the scenario from the Core contract.
        core.removeScenario(id);

        // Check if the token is transferred back to the scenario owner.
        assert(token.balanceOf(address(1)) == scenario.input_amount);
        // Check if the Core contract's token balance is 0 after removal.
        assert(token.balanceOf(address(core)) == 0);
    }

    // Function to test executing a scenario while the execution is paused.
    function testPausedExecuteScenario() external {
        // Add an empty scenario.
        uint64 id = core.addEmptyScenario(token, address(1));
        // Update the execution paused state to true.
        core.updateExecutionPauseState(true);

        // Expect the function call to revert with the reason "ExecutionPaused".
        vm.expectRevert(ExecutionPaused.selector);
        // Try to execute the scenario.
        core.executeScenario(address(1), id, 0);
    }

    // Function to test executing an invalid scenario ID.
    function testInvalidScenarioExecuteScenario() external {
        // Add an empty scenario.
        uint64 id = core.addEmptyScenario(token, address(1));

        // Expect the function call to revert with the reason "InvalidScenarioId".
        vm.expectRevert(InvalidScenarioId.selector);
        // Try to execute an invalid scenario ID.
        core.executeScenario(address(1), id + 1, 0);
    }

    // Function to test executing a scenario with an invalid actor.
    function testInvalidActorExecuteScenario() external {
        // Add an empty scenario.
        uint64 id = core.addEmptyScenario(token, address(1));

        // Expect the function call to revert with the reason "InvalidScenarioExecutor".
        vm.expectRevert(InvalidScenarioExecutor.selector);
        // Try to execute the scenario.
        core.executeScenario(address(1), id, 0);
    }

    // Function to test validation failure during scenario execution.
    function testValidationRevertExecuteScenario() external {
        // Create an invalid scenario with an invalid source kind (1).
        SourceData[] memory sources = new SourceData[](1);
        sources[0] = SourceData({
            addr: address(dexsource),
            kind: 1, // Invalid Kind
            input: "",
            condition: ""
        });

        ActionData[] memory actions = new ActionData[](1);
        actions[0] = ActionData({executor: address(transferExecutor), input: abi.encode(address(this))});

        uint64 id = core.addSomeScenario(token, address(1), sources, actions, TriggerType.ALL);

        // Simulate sender address being set to the actor.
        vm.prank(address(2));
        // Expect the function call to revert with the reason "SourceValidationError".
        vm.expectRevert(abi.encodeWithSelector(SourceValidationError.selector, address(dexsource)));

        // Try to execute the scenario.
        core.executeScenario(address(1), id, 0);
    }

    // Function to test validation failure during scenario execution.
    function testAnyTriggerValidationRevertExecuteScenario() external {
        // Create an invalid scenario with an invalid source kind (1).
        SourceData[] memory sources = new SourceData[](1);
        sources[0] = SourceData({
            addr: address(dexsource),
            kind: 1, // Invalid Kind
            input: "",
            condition: ""
        });

        ActionData[] memory actions = new ActionData[](1);
        actions[0] = ActionData({executor: address(transferExecutor), input: abi.encode(address(this))});

        uint64 id = core.addSomeScenario(token, address(1), sources, actions, TriggerType.ANY);

        // Simulate sender address being set to the actor.
        vm.prank(address(2));
        // Expect the function call to revert with the reason "NoValidSources".
        vm.expectRevert(NoValidSources.selector);

        // Try to execute the scenario.
        core.executeScenario(address(1), id, 0);
    }

    // Function to test execution failure during scenario execution.
    function testExecutionRevertExecuteScenario() external {
        // Create an invalid scenario with an invalid action executor input (empty data).
        SourceData[] memory sources = new SourceData[](1);
        sources[0] = SourceData({addr: address(dexsource), kind: 0, input: "", condition: ""});

        ActionData[] memory actions = new ActionData[](1);
        actions[0] = ActionData({executor: address(transferExecutor), input: ""});

        uint64 id = core.addSomeScenario(token, address(1), sources, actions, TriggerType.ALL);

        // Simulate sender address being set to the actor.
        vm.prank(address(2));
        // Expect the function call to revert with the reason "ActionExecutionError".
        vm.expectRevert(abi.encodeWithSelector(ActionExecutionError.selector, address(transferExecutor)));

        // Try to execute the scenario.
        core.executeScenario(address(1), id, 0);
    }

    // Function to test an invalid final output during scenario execution.
    function testInvalidFinalOutputExecuteScenario() external {
        // Create an invalid scenario with an executor that does nothing.
        SourceData[] memory sources = new SourceData[](1);
        sources[0] = SourceData({addr: address(dexsource), kind: 0, input: "", condition: ""});

        ActionData[] memory actions = new ActionData[](1);
        actions[0] = ActionData({executor: address(nothingExecutor), input: ""});

        uint64 id = core.addSomeScenario(token, address(1), sources, actions, TriggerType.ALL);

        // Simulate sender address being set to the actor.
        vm.prank(address(2));
        // Expect the function call to revert with the reason "InvalidScenarioFinalOutput".
        vm.expectRevert(InvalidScenarioFinalOutput.selector);

        // Try to execute the scenario.
        core.executeScenario(address(1), id, 0);
    }

    // Function to test executing a scenario successfully.
    function testExecuteScenario() external {
        // Create a valid scenario with a transfer action to address(3).
        SourceData[] memory sources = new SourceData[](1);
        sources[0] = SourceData({addr: address(dexsource), kind: 0, input: "", condition: ""});

        ActionData[] memory actions = new ActionData[](1);
        actions[0] = ActionData({executor: address(transferExecutor), input: abi.encode(address(3))});

        uint64 id = core.addSomeScenario(token, address(1), sources, actions, TriggerType.ALL);
        (, Scenario memory scenario) = core.getScenario(id);

        // Simulate sender address being set to the actor.
        vm.prank(address(2));

        // Execute the scenario.
        core.executeScenario(address(1), id, 0);

        // Check if the tokens are transferred to address(3) from the Core contract's address.
        assert(token.balanceOf(address(3)) == scenario.input_amount);
        // Check if the Core contract's token balance is 0 after successful execution.
        assert(token.balanceOf(address(core)) == 0);
    }
}
