<p align="center">
  <img src="https://pbs.twimg.com/media/GIZRzEIXcAADT9j.png"/>
</p>

# Double Token LeXscroW Ricardian Tripler

Smart contracts for the adoption of Double Token LeXscroW Agreement as a ['ricardian triple'](https://financialcryptography.com/mt/archives/001556.html). 

## How does it work?

- MetaLeX sets up the Ricardian tripler factory with the legal agreement form and approved factories as set forth in [Setup](https://github.com/MetaLex-Tech/RicardianTriplerDoubleTokenLeXscroW/tree/main/registry-contracts#setup)
- Parties to a prospective or existing Double Token LeXscroW navigate to an approved factory and become legally bound to a properly corresponding legal agreement by undertaking the steps set forth below

## Adoption/Signing

A few steps are required.

Firstly, the parties must come to an agreement regarding the proposed deal's terms including the tokens, amounts, any conditions, expiry time, and for the legal agreement:
- Confirming suitability and acceptance of the applicable MetaLeX form legal agreement's terms, the IPFS hash of which will be supplied to `legalAgreementURI`
- `governingLaw`: string input of the governing law that applies to the agreement 
- `disputeResolutionMethod`: string input of the dispute resolution method that applies to the agreement

Once the specifics of the `AgreementDetailsV1` struct pertaining to the parties' deal are determined, there are two final steps for adoption:

### 1. Propose and Deploy  

A party calls either:
* (a) `deployLexscrowAndProposeDoubleTokenLexscrowAgreement()` to deploy a Double Token LeXscroW contract with the same parameters included in the passed `AgreementDetailsV1`, or
* (b) `proposeDoubleTokenLexscrowAgreement()` including the parameters to an already-deployed Double Token LeXscroW in the passed `AgreementDetailsV1`, in each case in an `AgreementFactoryV1`.
  
The `AgreementFactoryV1` creates a `RicardianTriplerDoubleTokenLexscrow` agreement contract containing the provided proposed `AgreementDetailsV1`. In either case, the details include all of the parameters used to construct the Double Token LeXscroW contract, as well as each party's name and contact details, the legal agreement's URI, and elected governing law and dispute resolution method.

***If option (a) is chosen, the deployed Double Token LeXscroW will have an automatically-added condition that the deployed `RicardianTriplerDoubleTokenLexscrow` agreement be signed by both parties in order to execute.***

### 2. Confirm and Adopt

To confirm the details and formally adopt the `RicardianTriplerDoubleTokenLexscrow`, the other party to the applicable Double Token LeXscroW calls `confirmAndAdoptDoubleTokenLexscrowAgreement()` with `AgreementDetailsV1` matching the pending agreement's details, contract address, and the address of initial proposing party. The factory adds the `RicardianTriplerDoubleTokenLexscrow` contract address to the `DoubleTokenLexscrowRegistry`, updating both the `agreements`and `signedAgreement` mappings.

A user may check if a `RicardianTriplerDoubleTokenLexscrow` agreement was mutually signed (and thus recorded in the registry) by passing its address to the `signedAgreement` mapping in the `DoubleTokenLexscrowRegistry`; if it returns `true`, the agreement's details are then easily accessed by calling `getDetails()` directly in the `RicardianTriplerDoubleTokenLexscrow` contract address.
  
Each party's onchain transaction to propose and confirm (as applicable) the agreement details constitutes legally binding action, so each transacting address should represent the decision-making authority of the applicable party.




