//SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.18;

import "./SignatureValidator.sol";

/// @notice interface to DoubleTokenLexscrowFactory.sol to deploy a DoubleTokenLexscrow
interface IDoubleTokenLexscrowFactory {
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
    ) external;
}

/// @notice interface to DoubleTokenLexscrowRegistry.sol to record adoption
interface IDoubleTokenLexscrowRegistry {
    function recordAdoption(address confirmingParty, address proposingParty, address agreementDetailsAddress) external;
}

interface IRicardianTriplerDoubleTokenLexscrow {
    function getDetails() external view returns (AgreementDetailsV1 memory);

    function mutualSign() external;
}

/// @notice interface for a Lexscrow Condition
interface ICondition {
    function checkCondition(
        address _contract,
        bytes4 _functionSignature,
        bytes memory data
    ) external view returns (bool);
}

/// @notice OpenZeppelin's IERC165 interface for use with the ICondition interfaceId
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[ERC section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

///
/// STRUCTS AND TYPES
///

enum Logic {
    AND,
    OR
}

/// @notice the details of an account in an agreement
struct Account {
    // The address of the account (EOA or smart contract)
    address accountAddress;
    // The signature of the account. Optionally used to verify that this account has signed hashed agreement details
    bytes signature;
}

/// @notice the details of the agreement, consisting of all necessary information to deploy a DoubleTokenLexscrow and the legal agreement information
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
    /// @notice token contract address (`tokenContract1` or `tokenContract2`)
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

///
/// CONTRACTS
///

/// @title Ricardian Tripler Double Token LeXscroW
/// @author MetaLeX Labs, Inc.
/// @notice Contract that contains the Double Token LeXscroW agreement details that will be deployed by the Agreement Factory.
/// @dev If deployed via `deployLexscrowAndProposeDoubleTokenLexscrowAgreement()` in the Agreement Factory, this contract being mutually signed
/// and recorded in the registry becomes an immutable condition to the underlying DoubleTokenLexscrow's execution
contract RicardianTriplerDoubleTokenLexscrow {
    uint256 internal constant AGREEMENT_VERSION = 1;

    /// @notice store the deployer (AgreementFactory) in order to restrict ability to update `mutuallySigned`
    address internal deployer;

    /// @notice boolean indicating whether this agreement has been mutually signed
    bool public mutuallySigned;

    /// @notice The details of the agreement; accessible via `getDetails`
    AgreementDetailsV1 internal details;

    error RicardianTriplerDoubleTokenLexscrow_OnlyDeployer();

    event RicardianTriplerDoubleTokenLexscrow_MutuallySigned();

    /// @notice Constructor that sets the details of the agreement.
    /// @param _details the `AgreementDetailsV1` struct containing the details of the agreement.
    /// @param _adoptedTriplerCondition whether adoption of this tripler is a codified condition to Lexscrow execution (i.e. if the Lexscrow was deployed in `deployLexscrowAndProposeDoubleTokenLexscrowAgreement()`)
    constructor(AgreementDetailsV1 memory _details, bool _adoptedTriplerCondition) {
        deployer = msg.sender;

        // store everything but `conditions`
        details.partyA = _details.partyA;
        details.partyB = _details.partyB;
        details.lockedAssetPartyA = _details.lockedAssetPartyA;
        details.lockedAssetPartyB = _details.lockedAssetPartyB;
        details.expirationTime = _details.expirationTime;
        details.receipt = _details.receipt;
        details.legalAgreementURI = _details.legalAgreementURI;
        details.governingLaw = _details.governingLaw;
        details.disputeResolutionMethod = _details.disputeResolutionMethod;
        details.otherConditions = _details.otherConditions;

        // if `_adoptedTriplerCondition`, create a new array with an additional slot for the new condition and assign it to `details.conditions`,
        // else simply assign `_details.conditions` to `details.conditions`
        if (_adoptedTriplerCondition) {
            Condition[] memory updatedConditions = new Condition[](_details.conditions.length + 1);

            // copy the existing conditions into the new array
            for (uint256 i = 0; i < _details.conditions.length; i++) {
                updatedConditions[i] = _details.conditions[i];
            }

            // add the new condition to the last slot, with address(this) as the condition contract
            /// @dev `op` is hardcoded as `Logic.AND` because the tripler being mutually signed should always be a required condition
            updatedConditions[_details.conditions.length] = Condition({condition: address(this), op: Logic.AND});

            // assign `updatedConditions` to `details.conditions`
            /// @dev necessary for copying dynamic array of structs to storage
            for (uint256 i = 0; i < updatedConditions.length; ) {
                details.conditions.push(updatedConditions[i]);
                unchecked {
                    ++i; // cannot overflow without hitting gaslimit
                }
            }
        } else {
            for (uint256 i = 0; i < _details.conditions.length; ) {
                details.conditions.push(_details.conditions[i]);
                unchecked {
                    ++i; // cannot overflow without hitting gaslimit
                }
            }
        }
    }

    /// @notice Function for the `deployer` (intended to be the applicable Agreement Factory) to call indicating the Tripler
    /// is mutually signed and recorded in the registry
    function mutualSign() external {
        if (msg.sender != deployer) revert RicardianTriplerDoubleTokenLexscrow_OnlyDeployer();
        mutuallySigned = true;

        emit RicardianTriplerDoubleTokenLexscrow_MutuallySigned();
    }

    /// @notice function to check the condition that the tripler has been mutually signed
    /// @dev must comply with the ICondition interface
    /// @param _contract required for ICondition compliance but unused
    /// @param _functionSignature required for ICondition compliance but unused
    /// @param data required for ICondition compliance but unused
    /// @return mutuallySigned condition will return true if the boolean `mutuallySigned` indicates the tripler has been mutually signed
    function checkCondition(
        address _contract,
        bytes4 _functionSignature,
        bytes memory data
    ) external view returns (bool) {
        return mutuallySigned;
    }

    /// @notice for compliance with ICondition interface
    function supportsInterface(bytes4 interfaceId) external view virtual returns (bool) {
        return interfaceId == type(ICondition).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    /// @notice Function that returns the details of the agreement.
    /// @dev view function necessary to convert storage to memory automatically for the nested structs.
    /// @return details `AgreementDetailsV1` struct containing the details of the agreement.
    function getDetails() external view returns (AgreementDetailsV1 memory) {
        return details;
    }

    /// @notice Function that returns the version of the agreement.
    /// @return AGREEMENT_VERSION uint256 version of the tripler agreement, 1
    function version() external pure returns (uint256) {
        return AGREEMENT_VERSION;
    }
}

/// @title Ricardian Tripler Double Token LeXscroW AgreementV1Factory
/// @author MetaLeX Labs, Inc.
/// @notice Factory contract that creates new RicardianTriplerDoubleTokenLexscrow contracts if confirmed properly by both parties
/// and records their adoption in the DoubleTokenLexscrowRegistry. Either party may propose the agreement adoption, for the other to confirm.
/// Also contains an option to deploy a Double Token LeXscroW simultaneously with proposing an agreement to ensure the parameters are identical.
/// @dev various events emitted in the `registry` contract
contract AgreementV1Factory is SignatureValidator {
    uint256 internal constant FACTORY_VERSION = 1;

    /// @notice The DoubleTokenLexscrowRegistry contract.
    address public registry;

    /// @notice address of proposer of an agreement mapped to the pending agreement address, mapped to the second party address that must confirm adoption
    mapping(address proposer => mapping(address pendingAgreement => address pendingParty)) public pendingAgreement;

    /// @notice hashed agreement details mapped to whether they match a pending agreement
    mapping(bytes32 => bool) public pendingAgreementHash;

    /// @notice pending agreement hash mapped to whether it has a mutually-signed tripler condition (i.e. that the DoubleTokenLexscrow was deployed via this factory)
    mapping(bytes32 => bool) public signedTriplerCondition;

    error RicardianTriplerDoubleTokenLexscrow_NoPendingAgreement();
    error RicardianTriplerDoubleTokenLexscrow_NotParty();

    /// @notice event that fires if an address party to a DoubleTokenLeXscroW proposes a new RicardianTriplerDoubleTokenLexscrow contract
    event RicardianTriplerDoubleTokenLexscrow_Proposed(
        address indexed partyA,
        address indexed partyB,
        address indexed lexscrowAddress,
        address pendingAgreementAddress
    );

    /// @notice Constructor that sets the DoubleTokenLexscrowRegistry address.
    /// @dev no access control necessary as valid factories are set by the `admin` in the `registry` contract
    /// @param registryAddress The address of the DoubleTokenLexscrowRegistry contract.
    constructor(address registryAddress) {
        registry = registryAddress;
    }

    /// @notice for a party to an existing DoubleTokenLeXscroW to propose a new RicardianTriplerDoubleTokenLexscrow contract, which will be adopted if confirmed by the
    /// other party to the DoubleTokenLeXscroW.
    /// @dev this function is for where a DoubleTokenLexscrow is deployed prior to the Tripler; use `deployLexscrowAndProposeDoubleTokenLexscrowAgreement()` to simultaneously deploy the Lexscrow with an execution condition that the tripler agreement is mutually signed
    /// @param details The details of the proposed agreement, as an `AgreementDetailsV1` struct
    /// @param _lexscrow the contract address of the existing DoubleTokenLexscrow corresponding to the proposed tripler agreement
    /// @return _agreementAddress address of the pending `RicardianTriplerDoubleTokenLexscrow` agreement
    function proposeDoubleTokenLexscrowAgreement(
        AgreementDetailsV1 calldata details,
        address _lexscrow
    ) external returns (address) {
        RicardianTriplerDoubleTokenLexscrow agreementDetails = new RicardianTriplerDoubleTokenLexscrow(details, false);
        address _agreementAddress = address(agreementDetails);

        // if msg.sender is `partyA`, nested map it to the pending agreement to the address that needs to confirm adoption, and vice versa if `partyB`; else, revert
        if (msg.sender == details.partyA.partyBlockchainAddy)
            pendingAgreement[msg.sender][_agreementAddress] = details.partyB.partyBlockchainAddy;
        else if (msg.sender == details.partyB.partyBlockchainAddy)
            pendingAgreement[msg.sender][_agreementAddress] = details.partyA.partyBlockchainAddy;
        else revert RicardianTriplerDoubleTokenLexscrow_NotParty();

        pendingAgreementHash[keccak256(abi.encode(details))] = true;

        emit RicardianTriplerDoubleTokenLexscrow_Proposed(
            details.partyA.partyBlockchainAddy,
            details.partyB.partyBlockchainAddy,
            _lexscrow,
            _agreementAddress
        );
        return (_agreementAddress);
    }

    /// @notice for a party to an intended DoubleTokenLexscrow to (1) propose a new RicardianTriplerDoubleTokenLexscrow agreement contract, which will be adopted if confirmed by the
    /// other party, and (2) deploy the DoubleTokenLexscrow (with a condition that the tripler be mutually signed)
    /// @dev all of the deployment conditionals and checks for a DoubleTokenLexscrow are housed in `DoubleTokenLexscrow.sol`, so no need to duplicate here
    /// @param details The details of the proposed DoubleTokenLexscrow and agreement, as an `AgreementDetailsV1` struct-- the mutually-signed tripler 'condition' is added automatically to the details in the function
    /// @param _doubleTokenLexscrowFactory contract address of the DoubleTokenLexscrowFactory.sol which will be used to deploy a DoubleTokenLexscrow
    /// @return _agreementAddress address of the pending `RicardianTriplerDoubleTokenLexscrow` agreement
    function deployLexscrowAndProposeDoubleTokenLexscrowAgreement(
        AgreementDetailsV1 calldata details,
        address _doubleTokenLexscrowFactory
    ) external returns (address) {
        RicardianTriplerDoubleTokenLexscrow agreementDetails = new RicardianTriplerDoubleTokenLexscrow(details, true);
        address _agreementAddress = address(agreementDetails);

        /// fetch the updated agreement details (now including the Condition that the tripler is mutually signed) via `getDetails()`
        AgreementDetailsV1 memory _updatedDetails = IRicardianTriplerDoubleTokenLexscrow(_agreementAddress)
            .getDetails();

        // deploy the DoubleTokenLexscrow including the updated conditions
        IDoubleTokenLexscrowFactory(_doubleTokenLexscrowFactory).deployDoubleTokenLexscrow(
            false, // `partyA` must be identified-- cannot be an `openOffer`
            details.lockedAssetPartyA.totalAmount, // `totalAmount1`
            details.lockedAssetPartyB.totalAmount, // `totalAmount2`
            details.expirationTime,
            details.partyB.partyBlockchainAddy, // `partyB`, corresponding to `seller` in the Double Token LeXscroW, locking `lockedAssetPartyB`
            details.partyA.partyBlockchainAddy, // `partyA`, corresponding to `buyer` in the Double Token LeXscroW, locking `lockedAssetPartyA`
            details.lockedAssetPartyA.tokenContract, // `totalContract1`
            details.lockedAssetPartyB.tokenContract, // `totalContract2`
            details.receipt,
            _updatedDetails.conditions // updated conditions now including mutually-signed tripler
        );

        // if msg.sender is `partyA`, nested map it to the pending agreement to the address that needs to confirm adoption, and vice versa if `partyB`; else, revert
        if (msg.sender == details.partyA.partyBlockchainAddy)
            pendingAgreement[msg.sender][_agreementAddress] = details.partyB.partyBlockchainAddy;
        else if (msg.sender == details.partyB.partyBlockchainAddy)
            pendingAgreement[msg.sender][_agreementAddress] = details.partyA.partyBlockchainAddy;
        else revert RicardianTriplerDoubleTokenLexscrow_NotParty();

        bytes32 _detailsHash = keccak256(abi.encode(_updatedDetails));
        pendingAgreementHash[_detailsHash] = true;
        signedTriplerCondition[_detailsHash] = true;

        /// @dev `address(0)` placeholder for the lexscrow address, as it is emitted by the factory contract in `DoubleTokenLexscrowFactory_Deployment` but not returned in `deployDoubleTokenLexscrow`
        emit RicardianTriplerDoubleTokenLexscrow_Proposed(
            details.partyA.partyBlockchainAddy,
            details.partyB.partyBlockchainAddy,
            address(0),
            _agreementAddress
        );
        return (_agreementAddress);
    }

    /// @notice creates a new RicardianTriplerDoubleTokenLexscrow contract and records its adoption in the DoubleTokenLexscrowRegistry if called by the second party to `details`;
    /// i.e. the party address that did not initiate the adoption by calling `proposeDoubleTokenLexscrowAgreement`
    /// @param pendingAgreementAddress the address of the pending agreement being confirmed
    /// @param proposingParty the address of the party that initially proposed the pending Agreement
    /// @param details `AgreementDetailsV1` struct of the agreement details which will be hashed to ensure same parameters as the proposed agreement;
    /// if the DoubleTokenLexscrow was deployed via this factory, note that the `details` must include the mutually-signed tripler condition, which is:
    /// Condition({condition: `pendingAgreementAddress`, op: Logic.AND})
    function confirmAndAdoptDoubleTokenLexscrowAgreement(
        address pendingAgreementAddress,
        address proposingParty,
        AgreementDetailsV1 calldata details
    ) external {
        bytes32 pendingHash = keccak256(abi.encode(details));
        if (
            pendingAgreement[proposingParty][pendingAgreementAddress] != msg.sender ||
            !pendingAgreementHash[pendingHash]
        ) revert RicardianTriplerDoubleTokenLexscrow_NoPendingAgreement();

        delete pendingAgreement[proposingParty][pendingAgreementAddress];
        delete pendingAgreementHash[pendingHash];

        /// update `mutuallySigned` in the pending Ricardian Tripler agreement contract if the pending agreement hash such condition, otherwise not necessary as the subsequent registry recordation evidences mutual signature
        if (signedTriplerCondition[pendingHash])
            IRicardianTriplerDoubleTokenLexscrow(pendingAgreementAddress).mutualSign();

        /// now mutually signed and adopted, record this agreement in the registry
        IDoubleTokenLexscrowRegistry(registry).recordAdoption(msg.sender, proposingParty, pendingAgreementAddress);
    }

    /// @notice validate that an `account` has signed the hashed agreement details
    /// @param details `AgreementDetailsV1` struct of the agreement details to which `account` is being validated as signed
    /// @param account `Account` struct of the account which is being validated as having signed `details`
    function validateAccount(AgreementDetailsV1 calldata details, Account memory account) external view returns (bool) {
        bytes32 hash = keccak256(abi.encode(details));

        // Verify that the account's accountAddress signed the hashed details.
        return isSignatureValid(account.accountAddress, hash, account.signature);
    }

    /// @notice Function that returns the version of the agreement factory.
    /// @return FACTORY_VERSION, the uint256 version of the Agreement factory, 1
    function version() external pure returns (uint256) {
        return FACTORY_VERSION;
    }
}
