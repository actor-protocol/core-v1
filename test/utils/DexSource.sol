// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {ISource, SourceCall} from "src/interfaces/ISource.sol";

enum ConditionKind {
    GT,
    LT
}

struct Condition {
    ConditionKind kind;
    uint256 value;
}

enum SourceKind {SpotPrice}

contract DexSource is ISource {
    function validate(SourceCall calldata call) external pure {
        if (call.kind == uint8(SourceKind.SpotPrice)) {
            // address[] memory path = abi.decode(call.input, (address[]));
            // Condition memory condition = abi.decode(call.condition, (Condition));

            // Validation passed.
            return;
        }

        revert();
    }
}
