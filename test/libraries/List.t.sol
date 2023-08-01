// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "forge-std/Test.sol";

import {List} from "../../src/structs/SList.sol";
import {ListLibrary} from "../../src/libraries/List.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

contract ListUnitTest is Test {
    using ListLibrary for List;

    // Declare two instances of the List struct.
    List emptyList;
    List filledList;

    // An array of uint64 values to be used for testing the filledList.
    uint64[7] private listItems = [32, 48, 99, 17, 22, 81, 53];

    // Function to set up the initial state for testing.
    function setUp() external {
        // Fill the 'filledList' with values from 'listItems'.
        for (uint256 i = 0; i < listItems.length; i++) {
            filledList.insert(listItems[i]);
        }
    }

    // Internal function to test removal of elements from 'filledList'.
    function _filledRemoveElement(uint64 item) internal {
        // Store the current length of 'filledList'.
        uint64 length = filledList._length;
        // Get the index of the item in 'filledList'.
        uint64 index = filledList._vk[item];
        // Get the last item in 'filledList'.
        uint64 last_item = filledList._kv[length - 1];

        // Check that the item is removed successfully from 'filledList'.
        assert(filledList.remove(item));
        // Check that the item is no longer in 'filledList'.
        assert(!filledList.contains(item));
        // Check that the length of 'filledList' has decreased by one.
        assert(filledList._length == length - 1);
        // Check that the index of the removed item is set to 0.
        assert(filledList._vk[index] == 0);

        // If the removed item was not the last item in 'filledList'.
        if (index != length - 1) {
            // Check that the item at the previous index now contains the last item.
            assert(filledList._kv[index] == last_item);
        }
    }

    /* Empty list tests */

    // Function to test if an element is not present.
    function testEmptyContains(uint64 x) external view {
        assert(!emptyList.contains(x));
    }

    // Function to test double insertion of an element.
    function testDoubleInsert(uint64 x) external {
        assert(emptyList.insert(x));
        assert(!emptyList.insert(x));
    }

    // Function to test inserting an element.
    function testEmptyInsertElement(uint64 x) external {
        assert(emptyList.insert(x));
        assert(emptyList.contains(x));
        // Check that the inserted element is at index 0 in '_kv'.
        assert(emptyList._kv[0] == x);
        // Check that the inserted element is mapped to index 0 in '_vk'.
        assert(emptyList._vk[x] == 0);
    }

    // Function to test removing an element from the empty list (should fail as the element is not present).
    function testEmptyRemoveElement(uint64 x) external {
        assert(!emptyList.remove(x));
    }

    /* Filled list tests */

    // Function to test if the values in 'filledList' are correctly stored.
    function testValues() external view {
        for (uint64 i = 0; i < listItems.length; i++) {
            assert(filledList._kv[i] == listItems[i]);
        }
    }

    // Function to test if certain elements are present or not in 'filledList'.
    function testFilledContains() external view {
        assert(!filledList.contains(0));
        assert(!filledList.contains(34));

        for (uint256 i = 0; i < listItems.length; i++) {
            assert(filledList.contains(listItems[i]));
        }
    }

    // Function to test inserting an element in 'filledList' and checking its properties.
    function testFilledInsertElement(uint64 x) external {
        // If the element is already present in 'filledList', return without doing anything.
        if (filledList.contains(x)) return;

        // Store the current length of 'filledList'.
        uint64 length = filledList._length;

        // Insert the element into 'filledList'.
        assert(filledList.insert(x));
        // Check that the element is now present in 'filledList'.
        assert(filledList.contains(x));
        // Check that the element is inserted at the end of '_kv'.
        assert(filledList._kv[length] == x);
        // Check that the element is mapped to its correct index in '_vk'.
        assert(filledList._vk[x] == length);
    }

    // Function to test removing an unknown element from 'filledList' (should fail as the element is not present).
    function testFilledRemoveUnknownElement() external {
        assert(!filledList.remove(0));
    }

    // Function to test removing all elements from 'filledList'.
    function testFilledDrain() external {
        for (uint256 i = 0; i < listItems.length; i++) {
            _filledRemoveElement(listItems[i]);
        }
    }
}
