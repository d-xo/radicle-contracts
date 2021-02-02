// SPDX-License-Identifier: GPL-3.0-only
// solhint-disable no-empty-blocks
pragma solidity ^0.7.5;

import "@ensdomains/ens/contracts/ENS.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract Registrar {
    /// The ENS registry.
    ENS public immutable ens;

    /// The price oracle.
    address public oracleAddress;

    /// The Rad/Eth exchange.
    address public exchangeAddress;

    /// The Radicle ERC20 token.
    ERC20Burnable public immutable rad;

    // The namehash of the eth tld
    bytes32 public constant ethNode = keccak256(abi.encodePacked(bytes32(0), keccak256("eth")));

    /// The namehash of the node in the `eth` TLD
    bytes32 public constant domain = keccak256(abi.encodePacked(ethNode, keccak256("radicle")));

    /// The token ID for the node in the `eth` TLD
    uint256 public constant tokenId = uint(keccak256("radicle"));

    /// Registration fee in *USD*.
    uint256 public registrationFeeUsd = 10;

    /// Registration fee in *Radicle* (uRads).
    uint256 public registrationFeeRad = 1e18;

    /// The contract admin who can set fees.
    address public admin;

    /// @notice A name was registered.
    event NameRegistered(bytes32 indexed label, address indexed owner);

    /// Protects admin-only functions.
    modifier adminOnly {
        require(msg.sender == admin, "Only the admin can perform this action");
        _;
    }

    constructor(
        ENS _ens,
        ERC20Burnable _rad,
        address adminAddress
    ) {
        ens = _ens;
        rad = _rad;
        admin = adminAddress;
    }

    /// Register a subdomain using radicle tokens.
    function register(string calldata name, address owner) external {
        uint256 fee   = registrationFeeRad;

        require(valid(name), "Registrar::register: name must be valid");
        require(available(name), "Registrar::register: name must be available");
        require(rad.balanceOf(msg.sender) >= fee, "Registrar::register: insufficient funds");

        rad.burnFrom(msg.sender, fee);
        ens.setSubnodeOwner(domain, label, owner);

        emit NameRegistered(label, owner);
    }

    /// Check whether a name is valid.
    function valid(string memory name) public pure returns (bool) {
        uint256 len = bytes(name).length;
        return len > 0 && len <= 32;
    }

    /// Check whether a name is available for registration.
    function available(string memory name) public view returns (bool) {
        bytes32 label = keccak256(bytes(name));
        bytes32 node = namehash(domain, label);

        return !ens.recordExists(node);
    }

    /// Get the "namehash" of a label.
    function namehash(bytes32 parent, bytes32 label) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(parent, label));
    }

    // ADMIN FUNCTIONS

    /// Set the radicle registration fee.
    function setRadRegistrationFee(uint256 fee) public adminOnly {
        registrationFeeRad = fee;
    }

    /// Set the owner of the domain.
    function setDomainOwner(address newOwner) public adminOnly {
        // The name hash of 'eth'
        bytes32 ethNode = 0x93cdeb708b7545dc668eb9280176169d1c33cfd8ed6f04690a0bcc88a93fc4ae;
        address ethRegistrarAddr = ens.owner(ethNode);
        require(
            ethRegistrarAddr != address(0),
            "Registrar::setDomainOwner: no registrar found on ENS for the 'eth' domain"
        );
        ens.setRecord(domain, newOwner, newOwner, 0);
        IERC721 ethRegistrar = IERC721(ethRegistrarAddr);
        ethRegistrar.transferFrom(address(this), newOwner, tokenId);
    }

    /// Set a new admin
    function setAdmin(address _admin) public adminOnly {
        admin = _admin;
    }
}
