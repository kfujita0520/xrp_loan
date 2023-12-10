// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IBridgeDoorNative {

    event CreateClaim(uint256 indexed claimId, address indexed creator, address indexed sender);
    event Commit(uint256 indexed claimId, address indexed sender, uint256 value, address receiver);
    event CommitWithoutAddress(uint256 indexed claimId, address indexed sender, uint256 value);
    event Claim(uint256 indexed claimId, address indexed sender, uint256 value, address destination);
    event CreateAccountCommit(address indexed creator, address indexed destination, uint256 value, uint256 signatureReward);
    event AddClaimAttestation(uint256 indexed claimId, address indexed witness, uint256 value, address receiver);
    event AddCreateAccountAttestation(address indexed witness, address indexed receiver, uint256 value);
    event Credit(uint256 indexed claimId, address indexed receiver, uint256 value);
    event CreateAccount(address indexed receiver, uint256 value);

    struct AttestationClaimData {
        address destination;
        uint256 amount;
    }

    struct ClaimData {
        address creator;
        address sender; // address that will send the transaction on the other chain
        //mapping(address => AttestationClaimData) attestations;
        bool exists;
    }

    struct AddClaimAttestationData {
        uint256 claimId;
        uint256 amount;
        address sender;
        address destination;
    }

    struct AddCreateAccountAttestationData {
        address destination;
        uint256 amount;
        uint256 signatureReward;
    }

    struct CreateAccountData {
        uint256 signatureReward;
        //mapping(address => uint256) attestations;
        bool isCreated;
        bool exists;
    }


    function commit(address receiver, uint256 claimId, uint256 amount) external payable;
    function commitWithoutAddress(uint256 claimId, uint256 amount) external payable;
    function createAccountCommit(address destination, uint256 amount, uint256 signatureReward) external payable;
    function addCreateAccountAttestation(address destination, uint256 amount, uint256 signatureReward) external;
    function createClaimId(address sender) external payable returns (uint256);
    function claim(uint256 claimId, uint256 amount, address destination) external;
    function addClaimAttestation(uint256 claimId, uint256 amount, address sender, address destination) external;
    function getWitnesses() external view returns (address[] memory);
    function addAttestation(AddClaimAttestationData[] memory claimAttestations, AddCreateAccountAttestationData[] memory createAccountAttestations) external;

    //View
    function claims(uint256) external view returns (ClaimData memory);
    function createAccounts(address) external view returns (CreateAccountData memory);
    //function _safe() external view returns (GnosisSafeL2);
    function _tokenAddress() external view returns (address);
    function _lockingChainDoor() external view returns (address);
    function _lockingChainIssuer() external view returns (address);
    function _lockingChainIssue() external view returns (string memory);
    function _issuingChainDoor() external view returns (address);
    function _issuingChainIssuer() external view returns (address);
    function _issuingChainIssue() external view returns (string memory);
    function _isLocking() external view returns (bool);
    function _signatureReward() external view returns (uint256);
    function _minAccountCreateAmount() external view returns (uint256);
}