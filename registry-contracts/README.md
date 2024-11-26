# Double Token LeXscroW Tripler Registry

This directory houses smart contracts written in Solidity which serve three main purposes:

1. Allow parties to a Double Token LeXscroW (whether pre-existing or simultaneously deployed with the tripler agreement) to officially adopt the form agreement with their chosen governing law and dispute resolution.
2. If the Double Token LeXscroW is deployed simultaneously, make its execution immutably contingent upon mutual signature of the tripler agreement.
3. Store the agreement details on-chain for ease-of-use and persistent credibly neutral storage.
4. Allow for future agreement versions and adoptions without affecting prior agreements.

### Technical Details

This repository is built using [Foundry](https://book.getfoundry.sh/). See the installation instructions [here](https://github.com/foundry-rs/foundry#installation). To test the contracts, use `forge test`.

Contracts in this system:

-   `DoubleTokenLexscrowRegistry` - Where adopted agreement addresses are stored, new agreements are registered, and agreement factories are enabled / disabled.
-   `AgreementV1Factory` within [RicardianTriplerDoubleTokenLexscrow.sol](https://github.com/MetaLex-Tech/RicardianTriplerDoubleTokenLeXscroW/blob/0f86b80208cb85d76433c6f88896f1d09c00c83c/registry-contracts/src/RicardianTriplerDoubleTokenLexscrow.sol#L138) - Where parties adopt new agreement contracts.
-   `RicardianTriplerDoubleTokenLexscrow` - Adopted agreements proposed by a party and confirmed by the other party to a Double Token LeXscroW.
-   `SignatureValidator` - Used to determine whether a hash was validly signed by an address

### Setup

1. The `DoubleTokenLexscrowRegistry` contract is deployed by MetaLeX with the `admin` passed as a constructor argument.
2. The `AgreementV1Factory` contract is deployed by MetaLeX with the `DoubleTokenLexscrowRegistry` address passed as a constructor argument.
3. The `DoubleTokenLexscrowRegistry` `admin` calls `enableFactory()` on `DoubleTokenLexscrowRegistry` with the `AgreementV1Factory`'s address.

In the future MetaLeX may create new versions of the legal agreement, or adjust the agreement details struct. When this happens a new factory (e.g. `AgreementV2Factory`) may be deployed and enabled using the `enableFactory()` method. Optionally, the registry admin may disable old factories to prevent new adoptions using old agreement structures. 

## Propose and Deploy
### Deploy Proposed Agreement and LeXscroW

To simultaneously deploy a proposed agreement and a DoubleTokenLexscrow matching its `AgreementDetails`, a user may call `deployLexscrowAndProposeDoubleTokenLexscrowAgreement()` in the `AgreementV1Factory`, supplying:

| Param  | Type | Description 
| :---:  |:----:|  :---: |
| `details` | AgreementDetailsV1 | The details of the proposed DoubleTokenLexscrow and agreement, as an `AgreementDetailsV1` struct (see below) |
| `_doubleTokenLexscrowFactory` | address | Contract address of the DoubleTokenLexscrowFactory.sol which will be called in this function to deploy a DoubleTokenLexscrow |

AgreementDetailsV1 structs have the following syntax:
``` solidity
struct AgreementDetailsV1 {
    /// @notice The details of the parties adopting the agreement
    Party partyA;
    Party partyB;
    /// @notice The assets and amounts being escrowed by each party
    LockedAsset lockedAssetPartyA;
    LockedAsset lockedAssetPartyB;
    /// @notice block.timestamp expiration time
    uint256 expirationTime;
    /// @notice optional contract to return an informational receipt of a `LockedAsset` value, otherwise address(0)
    address receipt;
    /// @notice IPFS hash of the official MetaLeX LeXscroW Agreement version being agreed to which confirms all terms, and may contain a unique interface identifier
    string legalAgreementURI;
    /// @notice governing law for the Agreement
    string governingLaw;
    /// @notice dispute resolution elected by the parties
    string disputeResolutionMethod;
    /// @notice array of `Condition` structs upon which the DoubleTokenLexscrow is contingent
    Condition[] conditions;
    /// @notice any additional conditions precedent not included in `conditions`; note the DoubleTokenLexscrow's onchain execution will not be affected by these
    string otherConditions;
}
   /// @notice match `Condition` as defined in LexscrowConditionManager
struct Condition {
    address condition;
    Logic op;
}

/// @notice the details of a locked asset
struct LockedAsset {
    /// @notice token contract address (`tokenContract1` or `tokenContract2` in the DoubleTokenLexscrow)
    address tokenContract;
    /// @notice total amount of `tokenContract` locked
    uint256 totalAmount;
}

/// @notice details of a party (`partyB` or `partyA`): address, name, and contact information
struct Party {
    /// @notice The blockchain address of the party
    address partyBlockchainAddy;
    /// @notice The name of the party adopting the agreement
    string partyName;
    /// @notice The contact details of the party (required for legal notifications under the agreement)
    string contactDetails;
}

```
This function returns `_agreementAddress`: the contract address of the deployed and pending `RicardianTriplerDoubleTokenLexscrow` agreement. The newly deployed Double Token LeXscroW contract address is emitted in the `DoubleTokenLexscrowFactory_Deployment` event in the `_doubleTokenLexscrowFactory` contract.


### Deploy Proposed Agreement for an Existing LeXscroW

A party to an existing Double Token LeXscroW calls `proposeDoubleTokenLexscrowAgreement()` in the `AgreementV1Factory`, supplying:

| Param  | Type | Description 
| :---:  |:----:|  :---: |
| `details` | AgreementDetailsV1 |the `AgreementDetails` that match the proposer's pre-existing LeXscroW at the `_lexscrow` address|
| `_lexscrow` | address | The contract address of the existing DoubleTokenLexscrow corresponding to the proposed tripler agreement|

This function returns `_agreementAddress`: the contract address of the deployed and pending `RicardianTriplerDoubleTokenLexscrow` agreement


## Confirm and Adopt

The other party to the applicable Double Token LeXscroW, regardless of whether deployed simultaneously with the tripler agreement or pre-existing, calls `confirmAndAdoptDoubleTokenLexscrowAgreement()` in the `AgreementV1Factory`, supplying:

| Param  | Type | Description 
| :---:  |:----:|  :---: |
| `pendingAgreementAddress` | address | the contract address of the tripler agreement being confirmed |
| `proposingParty` | address | the address of the party that initially proposed the pending Agreement |
| `details` | AgreementDetailsV1 |agreement details which will be hashed to ensure they match the proposed agreement; if the DoubleTokenLexscrow was deployed via the tripler, the `details` must include the automatically-added tripler condition |

The confirming party may easily access the `details` by calling `getDetails()` in the `pendingAgreementAddress`, which returns its details struct. 

Upon confirmation, the factory (1) calls `mutualSign()` in the `pendingAgreementAddress`, and (2) adds the `RicardianTriplerDoubleTokenLexscrow` contract address to the `DoubleTokenLexscrowRegistry`.

Calling `confirmAndAdoptDoubleTokenLexscrowAgreement()` operates as a binding countersignature to the agreement, binding the two parties to the agreement. Once confirmed, the parties' agreement's `mutuallySigned` boolean variable, and the `signedAgreement` mapping in the `DoubleTokenLexscrowRegistry`, will be irrevocably set to `true`.

---

### Signed Accounts

For added security, parties may choose to sign their agreement for the scoped accounts. Both EOA and ERC-1271 signatures are supported and can be validated with the agreement's factory. 

#### Signing the Agreement Details

When preparing the final agreement details, prior to deploying onchain, the parties may sign the agreement details for any or all of the accounts under scope and store these signatures within the agreement details. A helper script to generate these account signatures for EOA accounts has been provided. To use it set the `SIGNER_PRIVATE_KEY` environment variable. Then, run the script using:

```
forge script GenerateAccountSignatureV1.s.sol --fork-url <YOUR_RPC_URL> -vvvv
```

#### Verification of Signed Accounts

Parties may use the agreement factory's `validateAccount()` method to verify that a given Account has consented to the agreement details.

## Querying Agreements

1. Query the `agreements` nested mapping in the `DoubleTokenLexscrowRegistry` contract (via the getter) a party's address and their index to get the protocol's `RicardianTriplerDoubleTokenLexscrow` address. This information is also emitted in the `DoubleTokenLexscrowRegistry_DoubleTokenLexscrowAdoption` event when `recordAdoption()` is called. To check if a `RicardianTriplerDoubleTokenLexscrow` was properly signed and recorded, a user may pass its address to the `signedAgreement` mapping in the `DoubleTokenLexscrowRegistry`; if it returns `true`, it was mutually signed and recorded.
2. Query the `RicardianTriplerDoubleTokenLexscrow` contract with `getDetails()` to get the structured agreement details.

Different versions may have different `AgreementDetails` structs. All `RicardianTriplerDoubleTokenLexscrow` and `AgreementFactory` contracts will include a `version()` method that can be used to infer the `AgreementDetails` structure.

## Deployment

The Double Token LeXscroW Registry may be deployed using the deterministic deployment proxy described here: https://github.com/Arachnid/deterministic-deployment-proxy, which is built into Foundry by default.

To deploy the registry to an EVM-compatible chain where it is not currently deployed:

1. Ensure the deterministic-deployment-proxy is deployed at 0x4e59b44847b379578588920cA78FbF26c0B4956C, and if it's not, deploy it using [the process mentioned above](https://github.com/Arachnid/deterministic-deployment-proxy).
2. Deploy the registry using the above proxy with salt `bytes32(0)` from the EOA that will become the registry admin. The file [`script/DoubleTokenLexscrowRegistryDeploy.s.sol`](script/DoubleTokenLexscrowRegistryDeploy.s.sol) is a convenience script for this task. To use it, set the `REGISTRY_DEPLOYER_PRIVATE_KEY` environment variable to a private key that can pay for the deployment transaction costs. Then, run the script using:

```
forge script DoubleTokenLexscrowRegistryDeploy --rpc-url <CHAIN_RPC_URL> --verify --etherscan-api-key <ETHERSCAN_API_KEY> --broadcast -vvvv
```
