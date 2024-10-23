//SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import {console} from "forge-std/console.sol";
import {ScriptBase} from "forge-std/Base.sol";
import {AgreementDetailsV1, Account, LockedAsset, Party} from "../src/RicardianTriplerDoubleTokenLexscrow.sol";

// This function generates an account signature for EOAs. For ERC-1271 contracts
// the method of signature generation may vary from contract to contract. Ensure
// that you always reset all signature fields to empty before hashing the agreement
// details.
contract GenerateAccountSignatureV1 is ScriptBase {
    function run() external view {
        uint256 signerPrivateKey = vm.envUint("SIGNER_PRIVATE_KEY");
        AgreementDetailsV1 memory details = getAgreementDetails();

        // Generate the signature
        bytes32 hash = keccak256(abi.encode(details));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        console.log("Account Address:");
        console.logAddress(vm.addr(signerPrivateKey));
        console.log("Generated Signature:");
        console.logBytes(signature);
    }

    /// @notice replace example with pertinent details
    function getAgreementDetails() internal pure returns (AgreementDetailsV1 memory details) {
        Account memory account = Account({
            accountAddress: address(0xeaA33ea82591611Ac749b875aBD80a465219ab40),
            signature: new bytes(0)
        });

        Party memory _partyA = Party({
            partyBlockchainAddy: address(1),
            partyName: "Party A",
            contactDetails: "partyA@email.com"
        });
        Party memory _partyB = Party({
            partyBlockchainAddy: address(2),
            partyName: "Party B",
            contactDetails: "partyB@email.com"
        });
        LockedAsset memory _lockedAssetPartyA = LockedAsset({tokenContract: address(3), totalAmount: 999999999999});

        details = AgreementDetailsV1({
            partyA: _partyA,
            partyB: _partyB,
            lockedAssetPartyA: _lockedAssetPartyA,
            lockedAssetPartyB: _lockedAssetPartyB,
            legalAgreementURI: "ipfs://testHash",
            governingLaw: "MetaLaW",
            disputeResolutionMethod: "coin flip",
            otherConditions: "mercury not in retrograde"
        });

        return details;
    }
}
