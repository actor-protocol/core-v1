// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {SourceData} from "./SSourceData.sol";
import {ActionData} from "./SActionData.sol";

enum TriggerType {
    ALL,
    ANY
}

struct Script {
    TriggerType trigger_type;
    SourceData[] sources_to_verify;
    ActionData[] actions_chain;
}

struct ScenarioWrapper {
    uint64 id;
    Scenario scenario;
}

struct Scenario {
    address owner;
    address actor;
    address input_token;
    uint256 input_amount;
    Script[] scripts;
}
