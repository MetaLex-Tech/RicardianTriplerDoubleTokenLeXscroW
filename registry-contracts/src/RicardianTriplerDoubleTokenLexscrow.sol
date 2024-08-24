// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "./SignatureValidator.sol";

interface IDoubleTokenLexscrowRegistry {
    function recordAdoption(address confirmingParty, address proposingParty, address agreementDetailsAddress) external;
}

///
/// STRUCTS
///

/// @notice the details of an account in an agreement
struct Account {
    // The address of the account (EOA or smart contract)
    address accountAddress;
    // The signature of the account. Optionally used to verify that this account has signed hashed agreement details
    bytes signature;
}

/// @notice the details of the agreement.
struct AgreementDetailsV1 {
    /// @notice The details of the parties adopting the agreement
    Party proposingParty;
    Party confirmingParty;
    /// @notice The assets and amounts being escrowed by each party
    LockedAsset lockedAssetproposingParty;
    LockedAsset lockedAssetconfirmingParty;
    /// @notice IPFS hash of the official MetaLeX LeXscroW Agreement version being agreed to which confirms all terms, and may contain a unique interface identifier
    string legalAgreementURI;
    /// @notice governing law for the Agreement
    string governingLaw;
    /// @notice dispute resolution elected by the parties
    string disputeResolutionMethod;
}

/// @notice the details of a locked asset
struct LockedAsset {
    /// @notice token contract address
    address tokenContract;
    /// @notice total amount of `tokenContract` locked
    uint256 totalAmount;
}

/// @notice details of a party: address, name, and contact information
struct Party {
    /// @notice The blockchain address of the party
    address confirmingPartylockchainAddy;
    /// @notice The name of the party adopting the agreement
    string partyName;
    /// @notice The contact details of the party (required for pre-notifying)
    string contactDetails;
}

///
/// CONTRACTS
///

/// @notice Contract that contains the AgreementDetails that will be deployed by the Agreement Factory.
contract RicardianTriplerDoubleTokenLexscrow {
    uint256 internal constant AGREEMENT_VERSION = 1;

    /// @notice The details of the agreement; accessible via `getDetails`
    AgreementDetailsV1 internal details;

    /// @notice Constructor that sets the details of the agreement.
    /// @param _details The details of the agreement.
    constructor(AgreementDetailsV1 memory _details) {
        details = _details;
    }

    /// @notice Function that returns the version of the agreement.
    function version() external pure returns (uint256) {
        return AGREEMENT_VERSION;
    }

    /// @notice Function that returns the details of the agreement.
    /// @dev view function necessary to convert storage to memory automatically for the nested structs.
    /// @return `AgreementDetailsV1` struct containing the details of the agreement.
    function getDetails() external view returns (AgreementDetailsV1 memory) {
        return details;
    }
}

/// @notice Factory contract that creates new RicardianTriplerDoubleTokenLexscrow contracts if confirmed properly by both parties
/// and records their adoption in the DoubleTokenLexscrowRegistry. Either party may propose the agreement adoption, for the other to confirm.
/// @dev various events emitted in the `registry` contract
contract AgreementV1Factory is SignatureValidator {
    uint256 internal constant FACTORY_VERSION = 1;

    /// @notice The DoubleTokenLexscrowRegistry contract.
    address public registry;

    /// @notice address of proposer of an agreement mapped to the pending agreement address, mapped to the second party address that must confirm adoption
    mapping(address proposer => mapping(address pendingAgreement => address pendingParty)) public pendingAgreement;

    /// @notice hashed agreement details mapped to whether they match a pending agreement
    mapping(bytes32 => bool) public pendingAgreementHash;

    error RicardianTriplerDoubleTokenLexscrow_NoPendingAgreement();
    error RicardianTriplerDoubleTokenLexscrow_NotParty();

    /// @notice event that fires if an address party to a DoubleTokenLeXscroW proposes a new RicardianTriplerDoubleTokenLexscrow contract
    event RicardianTriplerDoubleTokenLexscrow_Proposed(address proposer, address pendingAgreementAddress);

    /// @notice Constructor that sets the DoubleTokenLexscrowRegistry address.
    /// @dev no access control necessary as valid factories are set by the `admin` in the `registry` contract
    /// @param registryAddress The address of the DoubleTokenLexscrowRegistry contract.
    constructor(address registryAddress) {
        registry = registryAddress;
    }

    /// @notice for a party to a DoubleTokenLeXscroW to propose a new RicardianTriplerDoubleTokenLexscrow contract, which will be adopted if confirmed by the
    /// other party to the DoubleTokenLeXscroW.
    /// @param details The details of the proposed agreement, as an `AgreementDetailsV1` struct
    /// @return _agreementAddress address of the pending `RicardianTriplerDoubleTokenLexscrow` agreement
    function proposeDoubleTokenLexscrowAgreement(AgreementDetailsV1 memory details) external returns (address) {
        RicardianTriplerDoubleTokenLexscrow agreementDetails = new RicardianTriplerDoubleTokenLexscrow(details);
        address _agreementAddress = address(agreementDetails);

        // if msg.sender is proposingParty, nested map it to the pending agreement to the address that needs to confirm adoption, and vice versa if confirmingParty; else, revert
        if (msg.sender == details.proposingParty.confirmingPartylockchainAddy)
            pendingAgreement[msg.sender][_agreementAddress] = details.confirmingParty.confirmingPartylockchainAddy;
        else if (msg.sender == details.confirmingParty.confirmingPartylockchainAddy)
            pendingAgreement[msg.sender][_agreementAddress] = details.proposingParty.confirmingPartylockchainAddy;
        else revert RicardianTriplerDoubleTokenLexscrow_NotParty();

        pendingAgreementHash[keccak256(abi.encode(details))] = true;

        emit RicardianTriplerDoubleTokenLexscrow_Proposed(msg.sender, _agreementAddress);
        return (_agreementAddress);
    }

    /// @notice creates a new RicardianTriplerDoubleTokenLexscrow contract and records its adoption in the DoubleTokenLexscrowRegistry if called by the second party to `details`;
    /// i.e. the party address that did not initiate the adoption by calling `proposeDoubleTokenLexscrowAgreement`
    /// @param pendingAgreementAddress the address of the pending agreement being confirmed
    /// @param proposingParty the address of the party that initially proposed the pending Agreement
    /// @param details `AgreementDetailsV1` struct of the agreement details which will be hashed to ensure same parameters as the proposed agreement
    function confirmAndAdoptDoubleTokenLexscrowAgreement(
        address pendingAgreementAddress,
        address proposingParty,
        AgreementDetailsV1 memory details
    ) external {
        bytes32 pendingHash = keccak256(abi.encode(details));
        if (
            pendingAgreement[proposingParty][pendingAgreementAddress] != msg.sender ||
            !pendingAgreementHash[pendingHash]
        ) revert RicardianTriplerDoubleTokenLexscrow_NoPendingAgreement();

        delete pendingAgreement[proposingParty][pendingAgreementAddress];
        delete pendingAgreementHash[pendingHash];

        IDoubleTokenLexscrowRegistry(registry).recordAdoption(msg.sender, proposingParty, pendingAgreementAddress);
    }

    /// @notice validate that an `account` has signed the hashed agreement details
    /// @param details `AgreementDetailsV1` struct of the agreement details to which `account` is being validated as signed
    /// @param account `Account` struct of the account which is being validated as having signed `details`
    function validateAccount(AgreementDetailsV1 memory details, Account memory account) external view returns (bool) {
        bytes32 hash = keccak256(abi.encode(details));

        // Verify that the account's accountAddress signed the hashed details.
        return isSignatureValid(account.accountAddress, hash, account.signature);
    }

    /// @notice Function that returns the version of the agreement factory.
    function version() external pure returns (uint256) {
        return FACTORY_VERSION;
    }
}
