// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {List} from "../structs/SList.sol";

// This is a library that contains utility functions to work with the List struct.
library ListLibrary {
    /**
     * @dev Checks if a given value exists in the list.
     * @param self The reference to List.
     * @param _value The value.
     */
    function contains(List storage self, uint64 _value) public view returns (bool) {
        // The value is considered to be present in the list if the list is not empty,
        // and either the value's index exists in the value-key mapping or the value is mapped to index 0 in the key-value mapping.
        return (self._length != 0 && (self._vk[_value] != 0 || self._kv[0] == _value));
    }

    /**
     * @dev Inserts a value into the list.
     * @param self The reference to List.
     * @param _value The value.
     */
    function insert(List storage self, uint64 _value) public returns (bool) {
        // Check if the value is already present in the list using the contains function.
        // If the value is already present, return false, indicating that the insertion failed.
        if (contains(self, _value)) {
            return false;
        }

        // Insert the value into the key-value mapping, where the key is the current length of the list.
        self._kv[self._length] = _value;
        // Insert the index into the value-key mapping, where the value is the current length of the list.
        self._vk[_value] = self._length;

        // Increment the length of the list.
        self._length++;

        // Return true to indicate a successful insertion.
        return true;
    }

    /**
     * @dev Removes a value from the list.
     * @param self The reference to List.
     * @param _value The value.
     */
    function remove(List storage self, uint64 _value) public returns (bool) {
        // Check if the value exists in the list using the contains function.
        // If the value does not exist, return false, indicating that the removal failed.
        if (!contains(self, _value)) {
            return false;
        }

        // Get the index of the value in the value-key mapping.
        uint64 index = self._vk[_value];
        // Delete the value from the value-key mapping.
        delete self._vk[_value];

        // If the index is not pointing to the last element in the list:
        if (index != self._length - 1) {
            // Move the last element in the list to the index of the removed value.
            self._kv[index] = self._kv[self._length - 1];
            // Update the value-key mapping with the new index for the moved value.
            self._vk[self._kv[index]] = index;
        }

        // Delete the last element in the list.
        delete self._kv[self._length];
        // Decrement the length of the list.
        self._length--;

        // Return true to indicate a successful removal.
        return true;
    }
}
