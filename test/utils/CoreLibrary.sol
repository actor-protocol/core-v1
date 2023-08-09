// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "forge-std/Test.sol";

import {IERC20} from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import {Core} from "src/Core.sol";

import {RegisterType} from "src/enums/ERegisterType.sol";

import {Script, Scenario, ScenarioWrapper, TriggerType} from "src/structs/SScenario.sol";
import {SourceData} from "src/structs/SSourceData.sol";
import {ActionData} from "src/structs/SActionData.sol";

import {RegisterType} from "src/enums/ERegisterType.sol";
import {ExecutorCall} from "src/interfaces/IExecutor.sol";

library CoreLibrary {
    using SafeERC20 for IERC20;

    function setUp(Core core, address[] memory sources, address[] memory actions) external {
        // Register sources.
        for (uint8 i = 0; i < sources.length; i++) {
            core.updateRegister(RegisterType.Source, address(sources[i]), true);
        }

        // Register actions.
        for (uint8 i = 0; i < actions.length; i++) {
            core.updateRegister(RegisterType.Action, address(actions[i]), true);
        }
    }

    function addEmptyScenario(Core core, IERC20 token, address owner) external returns (uint64 id) {
        // Set up variables for the test scenario.
        uint256 defaultAmount = 1_000_000;

        // Transfer tokens to the owner for testing.
        token.safeTransfer(owner, defaultAmount);

        // Simulate sender address being set to the owner.
        Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D).startPrank(owner);

        // Approve the Core contract to transfer tokens on behalf of the owner.
        token.safeIncreaseAllowance(address(core), defaultAmount);

        // Create a script for the scenario.
        Script[] memory scripts = new Script[](1);
        Scenario memory scenario = Scenario({
            owner: owner,
            actor: address(2),
            input_token: address(token),
            input_amount: defaultAmount,
            scripts: scripts
        });

        // Add the scenario to the Core contract.
        id = core.addScenario(scenario);

        // Stop the sender address simulation.
        Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D).stopPrank();

        // Check if the owner's token balance is 0 (tokens transferred to Core contract).
        assert(token.balanceOf(owner) == 0);
        // Check if the Core contract's token balance is equal to the initial amount.
        assert(token.balanceOf(address(core)) == defaultAmount);
    }

    function addSomeScenario(
        Core core,
        IERC20 token,
        address owner,
        SourceData[] memory sources,
        ActionData[] memory actions,
        TriggerType trigger_type
    ) external returns (uint64 id) {
        // Set up variables for the test scenario.
        uint256 defaultAmount = 1_000_000;

        // Transfer tokens to the owner for testing.
        token.safeTransfer(owner, defaultAmount);

        // Simulate sender address being set to the owner.
        Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D).startPrank(owner);

        // Approve the Core contract to transfer tokens on behalf of the owner.
        token.safeIncreaseAllowance(address(core), defaultAmount);

        // Create a script for the scenario.
        Script[] memory scripts = new Script[](1);
        scripts[0].trigger_type = trigger_type;
        scripts[0].sources_to_verify = sources;
        scripts[0].actions_chain = actions;

        Scenario memory scenario = Scenario({
            owner: owner,
            actor: address(2),
            input_token: address(token),
            input_amount: defaultAmount,
            scripts: scripts
        });

        // Add the scenario to the Core contract.
        id = core.addScenario(scenario);

        // Stop the sender address simulation.
        Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D).stopPrank();

        // Check if the owner's token balance is 0 (tokens transferred to Core contract).
        assert(token.balanceOf(owner) == 0);
        // Check if the Core contract's token balance is equal to the initial amount.
        assert(token.balanceOf(address(core)) == defaultAmount);
    }
}
