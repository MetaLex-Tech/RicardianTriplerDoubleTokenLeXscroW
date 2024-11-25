//SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";
import "../src/DoubleTokenLexscrowRegistry.sol";
import "../src/RicardianTriplerDoubleTokenLexscrow.sol";

contract RicardianTriplerDoubleTokenLexscrowTest is Test {
    DoubleTokenLexscrowRegistry registry;
    AgreementV1Factory factory;

    Condition[] internal emptyConditions;

    uint256 internal constant FACTORY_VERSION = 1;
    uint256 internal constant AGREEMENT_VERSION = 1;

    uint256 mockKey = 100;
    uint256 firstPartyNonce;
    address firstParty = address(1);
    address secondParty = address(2);

    mapping(address => AgreementDetailsV1) public details;

    function setUp() external {
        _setDetails();
        address fakeAdmin = address(0xaa);

        registry = new DoubleTokenLexscrowRegistry(fakeAdmin);
        factory = new AgreementV1Factory(address(registry));

        vm.prank(fakeAdmin);
        registry.enableFactory(address(factory));
    }

    function testVersion() public {
        assertEq(FACTORY_VERSION, factory.version(), "factory version != 1");
        AgreementDetailsV1 storage mockDetails = details[address(this)];
        RicardianTriplerDoubleTokenLexscrow newAgreement = new RicardianTriplerDoubleTokenLexscrow(mockDetails, false);
        assertEq(AGREEMENT_VERSION, newAgreement.version(), "agreement version != 1");
    }

    function testProposeAndConfirmDoubleTokenLexscrowAgreement() public {
        ++firstPartyNonce;
        vm.prank(firstParty);
        AgreementDetailsV1 storage mockDetails = details[address(this)];
        address _newAgreement = factory.proposeDoubleTokenLexscrowAgreement(mockDetails, address(1));
        bytes32 _pendingHash = keccak256(abi.encode(mockDetails));
        assertEq(factory.pendingAgreement(firstParty, _newAgreement), secondParty, "secondParty should be pending");
        assertTrue(factory.pendingAgreementHash(_pendingHash), "_pendingHash should be mapped to true");

        vm.prank(secondParty);
        factory.confirmAndAdoptDoubleTokenLexscrowAgreement(_newAgreement, firstParty, mockDetails);

        assertEq(registry.agreements(firstParty, firstPartyNonce), _newAgreement, "agreement address does not match");
        assertTrue(registry.signedAgreement(_newAgreement), "signedAgreement should be true for new agreement address");

        // if successful, this mapping should be deleted
        assertEq(
            address(0),
            factory.pendingAgreement(firstParty, _newAgreement),
            "pending Agreement mapping not reset"
        );
    }

    function testProposeAndConfirmDoubleTokenLexscrowAgreement_invalid(address _randomAddr) public {
        ++firstPartyNonce;
        AgreementDetailsV1 storage mockDetails = details[address(this)];
        vm.prank(firstParty);
        address _newAgreement = factory.proposeDoubleTokenLexscrowAgreement(mockDetails, address(1));
        bytes32 _pendingHash = keccak256(abi.encode(mockDetails));
        assertEq(factory.pendingAgreement(firstParty, _newAgreement), secondParty, "secondParty should be pending");
        assertTrue(factory.pendingAgreementHash(_pendingHash), "_pendingHash should be mapped to true");

        vm.prank(_randomAddr);
        if (_randomAddr != secondParty) {
            vm.expectRevert();
            factory.confirmAndAdoptDoubleTokenLexscrowAgreement(_newAgreement, firstParty, mockDetails);

            // 'secondParty' should still be pending
            assertEq(secondParty, factory.pendingAgreement(firstParty, _newAgreement), "second party not pending");
            assertTrue(
                factory.pendingAgreementHash(_pendingHash),
                "_pendingHash should be mapped to true as still pending"
            );
            assertTrue(
                !registry.signedAgreement(_newAgreement),
                "signedAgreement should remain false for new agreement address"
            );
        }
    }

    function testDeployLexscrowAndProposeDoubleTokenLexscrowAgreement() public {
        ++firstPartyNonce;
        AgreementDetailsV1 storage mockDetails = details[address(this)];
        vm.prank(firstParty);
        address _newAgreement = factory.deployLexscrowAndProposeDoubleTokenLexscrowAgreement(
            mockDetails,
            address(this)
        );

        AgreementDetailsV1 memory _updatedDetails = IRicardianTriplerDoubleTokenLexscrow(_newAgreement).getDetails();

        /// @dev hash will include the added tripler condition, get it from the agreement contract
        bytes32 _pendingHash = keccak256(abi.encode(_updatedDetails));
        assertEq(factory.pendingAgreement(firstParty, _newAgreement), secondParty, "secondParty should be pending");
        assertTrue(factory.pendingAgreementHash(_pendingHash), "_pendingHash should be mapped to true");

        vm.prank(secondParty);
        /// @dev confirming party should match the details pulled from the pending agreement
        bytes32 _updatedHash = keccak256(abi.encode(_updatedDetails));
        if (_updatedHash != _pendingHash) {
            vm.expectRevert();
            factory.confirmAndAdoptDoubleTokenLexscrowAgreement(_newAgreement, firstParty, _updatedDetails);
        } else {
            assertEq(_updatedHash, _pendingHash, "hashes do not match");
            factory.confirmAndAdoptDoubleTokenLexscrowAgreement(_newAgreement, firstParty, _updatedDetails);
        }
        assertEq(registry.agreements(firstParty, firstPartyNonce), _newAgreement, "agreement address does not match");
        assertTrue(registry.signedAgreement(_newAgreement), "signedAgreement should be true for new agreement address");

        // if successful, this mapping should be deleted
        assertEq(
            address(0),
            factory.pendingAgreement(firstParty, _newAgreement),
            "pending Agreement mapping not reset"
        );
    }

    function testDeployLexscrowAndProposeDoubleTokenLexscrowAgreement_invalid(address _randomAddr) public {
        ++firstPartyNonce;
        AgreementDetailsV1 storage mockDetails = details[address(this)];
        vm.prank(firstParty);
        address _newAgreement = factory.deployLexscrowAndProposeDoubleTokenLexscrowAgreement(
            mockDetails,
            address(this)
        );
        // deliberately do not add the tripler condition by using the unaltered `mockDetails` rather than using `getDetails()`
        bytes32 _wrongPendingHash = keccak256(abi.encode(mockDetails));

        AgreementDetailsV1 memory _updatedDetails = IRicardianTriplerDoubleTokenLexscrow(_newAgreement).getDetails();

        bytes32 _pendingHash = keccak256(abi.encode(_updatedDetails));
        assertEq(factory.pendingAgreement(firstParty, _newAgreement), secondParty, "secondParty should be pending");
        assertTrue(
            !factory.pendingAgreementHash(_wrongPendingHash),
            "_wrongPendingHash should be wrong, so pendingAgreementHash should be false"
        );
        assertTrue(factory.pendingAgreementHash(_pendingHash), "hash not pending");

        // ensure hashes do not match
        bytes32 _updatedHash = keccak256(abi.encode(_updatedDetails));
        assertTrue(_updatedHash != _wrongPendingHash, "hashes unexpectedly match");

        vm.prank(_randomAddr);
        if (_randomAddr != secondParty) {
            vm.expectRevert(); // should revert if not the second party calling
            factory.confirmAndAdoptDoubleTokenLexscrowAgreement(_newAgreement, firstParty, _updatedDetails);

            // 'secondParty' should still be pending
            assertEq(secondParty, factory.pendingAgreement(firstParty, _newAgreement), "second party not pending");
            assertTrue(
                factory.pendingAgreementHash(_pendingHash),
                "_pendingHash should be mapped to true as still pending"
            );
            assertTrue(
                !registry.signedAgreement(_newAgreement),
                "signedAgreement should remain false for new agreement address"
            );
        } else {
            // ensure second party calling with the wrong details still reverts
            vm.expectRevert();
            factory.confirmAndAdoptDoubleTokenLexscrowAgreement(_newAgreement, firstParty, mockDetails);
        }
    }

    function testMutualSign_invalid(address _addr) public {
        AgreementDetailsV1 storage mockDetails = details[address(this)];
        vm.prank(firstParty);
        address _newAgreement = factory.deployLexscrowAndProposeDoubleTokenLexscrowAgreement(
            mockDetails,
            address(this)
        );
        vm.prank(_addr);
        if (_addr != address(this)) vm.expectRevert();
        IRicardianTriplerDoubleTokenLexscrow(_newAgreement).mutualSign();
    }

    function testValidateAccount() public {
        Account memory account = Account({accountAddress: vm.addr(mockKey), signature: new bytes(0)});
        AgreementDetailsV1 storage mockDetails = details[address(this)];
        bytes32 hash = keccak256(abi.encode(mockDetails));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(mockKey, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        account.signature = signature;

        bool isValid = factory.validateAccount(mockDetails, account);
        assertTrue(isValid);
    }

    function testValidateAccount_invalid() public {
        Account memory account = Account({accountAddress: vm.addr(mockKey), signature: new bytes(0)});
        uint256 fakeKey = 200;
        AgreementDetailsV1 storage mockDetails = details[address(this)];
        bytes32 hash = keccak256(abi.encode(mockDetails));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(fakeKey, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        account.signature = signature;

        bool isValid = factory.validateAccount(mockDetails, account);
        assertTrue(!isValid);
    }

    /// @dev simply mocked for testing, as this function is covered in the DoubleTokenLexscrowFactory.t.sol tests
    function deployDoubleTokenLexscrow(
        bool openOffer,
        uint256 totalAmount1,
        uint256 totalAmount2,
        uint256 expirationTime,
        address seller,
        address buyer,
        address tokenContract1,
        address tokenContract2,
        address receipt,
        Condition[] calldata _conditions
    ) public {}

    function _setDetails() public {
        AgreementDetailsV1 storage mockDetails = details[address(this)];

        mockDetails.partyA = Party({
            partyBlockchainAddy: address(1),
            partyName: "Party A",
            contactDetails: "partyA@email.com"
        });
        mockDetails.partyB = Party({
            partyBlockchainAddy: address(2),
            partyName: "Party B",
            contactDetails: "partyB@email.com"
        });
        mockDetails.lockedAssetPartyA = LockedAsset({tokenContract: address(3), totalAmount: 999999999999});
        mockDetails.lockedAssetPartyB = LockedAsset({tokenContract: address(4), totalAmount: 8888888888888});
        mockDetails.expirationTime = 9999999999999999;
        mockDetails.receipt = address(0);
        mockDetails.legalAgreementURI = "ipfs://testHash";
        mockDetails.governingLaw = "MetaLaW";
        mockDetails.disputeResolutionMethod = "coin flip";
        mockDetails.conditions = emptyConditions;
        mockDetails.otherConditions = "mercury not in retrograde";
    }

    /** for reference, the logic for the automatically-added required tripler condition
        Condition[] memory updatedConditions = new Condition[](1);

        // add the new condition to the last slot, with address(this) as the condition contract
        /// @dev `op` is hardcoded as `Logic.AND` because the tripler being mutually signed should always be a required condition
        updatedConditions[emptyConditions.length] = Condition({condition: address(this), op: Logic.AND});

        // assign `updatedConditions` to `details.conditions`
        /// @dev necessary for copying dynamic array of structs to storage
        for (uint256 i = 0; i < updatedConditions.length; ) {
            mockDetails.conditions.push(updatedConditions[i]);
            unchecked {
                ++i; // cannot overflow without hitting gaslimit
            }
        }
        return mockDetails;
    } */
}
