//SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.18;

/// @title Double Token LeXscroW Registry
/// @author MetaLeX Labs, Inc.
/// @notice `admin`-controlled registry contract for valid agreement factories which records duly adopted Double Token LeXscroW Agreements
/// @dev `admin` sets valid factories with approved agreement forms
contract DoubleTokenLexscrowRegistry {
    /// @notice admin address used to enable or disable factories.
    address public admin;
    /// @notice pending new admin address
    address public _pendingAdmin;

    /// @notice A mapping which records the approved agreement factories.
    mapping(address factory => bool) public agreementFactories;

    /// @notice maps an address to whether it is a confirmed and adopted agreement;
    /// if true, user may call `getDetails()` on such address to easily view the details
    /// @dev enables public getter function to check an agreement address more easily than via the nested `agreements` mapping
    mapping(address => bool) public signedAgreement;

    /// @notice maps an address to a counter in order to support multiple adopted agreements by one address
    mapping(address => uint256) private nonce;

    /// @notice maps an address to their index of adopted agreements to the agreement details for the applicable index
    mapping(address adopter => mapping(uint256 index => address details)) public agreements;

    ///
    /// EVENTS
    ///

    event DoubleTokenLexscrowRegistry_AdminUpdated(address newAdmin);

    /// @notice An event that records when an address either newly adopts the Double Token LeXscroW Agreement, or alters its previous terms.
    event DoubleTokenLexscrowRegistry_DoubleTokenLexscrowAdoption(
        address confirmingParty,
        address proposingParty,
        address details
    );

    /// @notice An event that records when an address is newly enabled as a factory.
    event DoubleTokenLexscrowRegistry_FactoryEnabled(address factory);

    /// @notice An event that records when an address is newly disabled as a factory.
    event DoubleTokenLexscrowRegistry_FactoryDisabled(address factory);

    ///
    /// ERRORS
    ///

    error DoubleTokenLexscrowRegistry_OnlyAdmin();
    error DoubleTokenLexscrowFactory_OnlyPendingAdmin();
    error DoubleTokenLexscrowRegistry_OnlyFactories();
    error DoubleTokenLexscrowRegistry_ZeroAddress();

    /// @notice restrict access to admin-only functions.
    modifier onlyAdmin() {
        if (msg.sender != admin) revert DoubleTokenLexscrowRegistry_OnlyAdmin();
        _;
    }

    /// @notice Sets the admin address to the provided address.
    constructor(address _admin) {
        admin = _admin;
    }

    /// @notice Officially adopt the agreement, or modify its terms if already adopted. Only callable by approved factories.
    /// @dev updates mappings for each party to the agreement and records the agreement address as a `signedAgreement`
    /// @param confirmingParty address that confirmed agreement adoption
    /// @param proposingParty address that proposed the agreement, subsequently confirmed as adopted by `confirmingParty`
    /// @param agreementDetailsAddress The new details of the agreement.
    function recordAdoption(address confirmingParty, address proposingParty, address agreementDetailsAddress) external {
        if (!agreementFactories[msg.sender]) revert DoubleTokenLexscrowRegistry_OnlyFactories();
        uint256 _confirmingPartyNonce = ++nonce[confirmingParty];
        uint256 _proposingPartyNonce = ++nonce[proposingParty];

        signedAgreement[agreementDetailsAddress] = true;
        agreements[confirmingParty][_confirmingPartyNonce] = agreementDetailsAddress;
        agreements[proposingParty][_proposingPartyNonce] = agreementDetailsAddress;

        emit DoubleTokenLexscrowRegistry_DoubleTokenLexscrowAdoption(
            confirmingParty,
            proposingParty,
            agreementDetailsAddress
        );
    }

    /// @notice Enables an address as a factory.
    /// @param factory The address to enable.
    function enableFactory(address factory) external onlyAdmin {
        agreementFactories[factory] = true;
        emit DoubleTokenLexscrowRegistry_FactoryEnabled(factory);
    }

    /// @notice Disables an address as an factory.
    /// @param factory The address to disable.
    function disableFactory(address factory) external onlyAdmin {
        delete agreementFactories[factory];
        emit DoubleTokenLexscrowRegistry_FactoryDisabled(factory);
    }

    /// @notice allows the `admin` to propose a replacement to their address. First step in two-step address change, as `_newAdmin` will subsequently need to call `acceptAdminRole()`
    /// @dev use care in updating `admin` as it must have the ability to call `acceptAdminRole()`, or once it needs to be replaced, `updateAdmin()`
    /// @param _newAdmin new address for pending `admin`, who must accept the role by calling `acceptAdminRole`
    function updateAdmin(address _newAdmin) external onlyAdmin {
        if (_newAdmin == address(0)) revert DoubleTokenLexscrowRegistry_ZeroAddress();

        _pendingAdmin = _newAdmin;
    }

    /// @notice allows the pending new admin to accept the role transfer, and receive fees
    /// @dev access restricted to the address stored as `_pendingAdmin` to accept the two-step change. Transfers `admin` role to the caller and deletes `_pendingAdmin` to reset.
    function acceptAdminRole() external {
        address _sender = msg.sender;
        if (_sender != _pendingAdmin) revert DoubleTokenLexscrowFactory_OnlyPendingAdmin();
        delete _pendingAdmin;
        admin = _sender;
        emit DoubleTokenLexscrowRegistry_AdminUpdated(admin);
    }
}
