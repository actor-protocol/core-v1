// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

struct SourceCall {
    uint8 kind;
    bytes input;
    bytes condition;
}

interface ISource {
    function validate(SourceCall calldata) external;
}
