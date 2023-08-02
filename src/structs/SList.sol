// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

/**
 * @dev Data structure that supports insert and remove operations in O(1) time.
 */
struct List {
    uint64 _length;
    mapping(uint64 => uint64) _kv;
    mapping(uint64 => uint64) _vk;
}
