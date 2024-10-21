//SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";
import "../src/DoubleTokenLexscrowRegistry.sol";

contract DoubleTokenLexscrowRegistryTest is Test {
    address admin;
    DoubleTokenLexscrowRegistry registry;

    function setUp() public {
        admin = address(0xaa);
        registry = new DoubleTokenLexscrowRegistry(admin);
    }

    function test_recordAdoption() public {
        address factory = address(0xff);
        address agreement = address(0xbb);
        address confirmingParty = address(0xee);
        address proposingParty = address(0xcc);

        vm.prank(admin);
        registry.enableFactory(factory);

        vm.prank(factory);
        registry.recordAdoption(confirmingParty, proposingParty, agreement);
    }

    function test_adoptDoubleTokenLexscrow_disabledFactory() public {
        address factory = address(0xff);
        address agreement = address(0xbb);
        address confirmingParty = address(0xee);
        address proposingParty = address(0xcc);

        vm.prank(admin);
        registry.disableFactory(factory);

        vm.prank(factory);
        vm.expectRevert(); //only approved, non-disabled factories
        registry.recordAdoption(confirmingParty, proposingParty, agreement);
    }

    function test_enableFactory() public {
        address factory = address(0xff);

        vm.prank(admin);
        registry.enableFactory(factory);

        assertTrue(registry.agreementFactories(factory));
    }

    function test_enableFactory_notAdmin() public {
        address factory = address(0xff);
        address fakeAdmin = address(0xcc);

        vm.prank(fakeAdmin);
        vm.expectRevert(); //only admin can enable
        registry.enableFactory(factory);
    }

    function test_disableFactory() public {
        address factory = address(0xff);

        vm.prank(admin);
        registry.disableFactory(factory);

        assertTrue(!registry.agreementFactories(factory));
    }

    function test_disableFactory_notAdmin() public {
        address factory = address(0xff);
        address fakeAdmin = address(0xcc);

        vm.prank(fakeAdmin);
        vm.expectRevert(); // only admin can disable
        registry.disableFactory(factory);
    }

    function testUpdateAdmin(address _addr2) public {
        address newAdmin = address(0xbb);

        vm.prank(admin);
        registry.updateAdmin(newAdmin);

        vm.startPrank(_addr2);
        // make sure wrong address causes revert
        if (newAdmin != _addr2) {
            vm.expectRevert();
            registry.acceptAdminRole();
        }
        vm.stopPrank();
        vm.startPrank(newAdmin);
        registry.acceptAdminRole();
        assertEq(registry.admin(), newAdmin, "admin address did not update");
    }

    function testUpdateAdminRights_notAdmin() public {
        address fakeAdmin = address(0xcc);
        address newAdmin = address(0xbb);

        vm.prank(fakeAdmin);
        vm.expectRevert(); // only admin can update itself
        registry.updateAdmin(newAdmin);
    }
}
