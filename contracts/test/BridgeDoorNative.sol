// Sources flattened with hardhat v2.11.0 https://hardhat.org

// File @openzeppelin/contracts/utils/Context.sol@v4.6.0


// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}


// File @openzeppelin/contracts/access/Ownable.sol@v4.6.0


// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

pragma solidity ^0.8.0;

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}


// File @openzeppelin/contracts/utils/Counters.sol@v4.6.0


// OpenZeppelin Contracts v4.4.1 (utils/Counters.sol)

pragma solidity ^0.8.0;

/**
 * @title Counters
 * @author Matt Condon (@shrugs)
 * @dev Provides counters that can only be incremented, decremented or reset. This can be used e.g. to track the number
 * of elements in a mapping, issuing ERC721 ids, or counting request ids.
 *
 * Include with `using Counters for Counters.Counter;`
 */
library Counters {
    struct Counter {
        // This variable should never be directly accessed by users of the library: interactions must be restricted to
        // the library's function. As of Solidity v0.5.2, this cannot be enforced, though there is a proposal to add
        // this feature: see https://github.com/ethereum/solidity/issues/4637
        uint256 _value; // default: 0
    }

    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }

    function increment(Counter storage counter) internal {
        unchecked {
            counter._value += 1;
        }
    }

    function decrement(Counter storage counter) internal {
        uint256 value = counter._value;
        require(value > 0, "Counter: decrement overflow");
        unchecked {
            counter._value = value - 1;
        }
    }

    function reset(Counter storage counter) internal {
        counter._value = 0;
    }
}


// File @openzeppelin/contracts/security/Pausable.sol@v4.6.0


// OpenZeppelin Contracts v4.4.1 (security/Pausable.sol)

pragma solidity ^0.8.0;

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() {
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}


// File contracts/BridgeDoor.sol


pragma solidity ^0.8.0;



contract Enum {
    enum Operation {
        Call,
        DelegateCall
    }
}

interface GnosisSafeL2 {
    function execTransactionFromModule(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation
    ) external returns (bool success);

    function getOwners() external view returns (address[] memory);

    function getThreshold() external view returns (uint256);

    function isOwner(address owner) external view returns (bool);
}

abstract contract BridgeDoor is Ownable, Pausable {
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
        mapping(address => AttestationClaimData) attestations;
        bool exists;
    }

    struct AddClaimAttestationData {
        uint256 claimId;
        uint256 amount;
        address sender;
        address destination;
    }

    struct CreateAccountData {
        uint256 signatureReward;
        mapping(address => uint256) attestations;
        bool isCreated;
        bool exists;
    }

    struct AddCreateAccountAttestationData {
        address destination;
        uint256 amount;
        uint256 signatureReward;
    }

    mapping(uint256 => ClaimData) public claims;
    mapping(address => CreateAccountData) public createAccounts;

    GnosisSafeL2 public _safe;
    address public _tokenAddress;
    address public _lockingChainDoor;
    address public _lockingChainIssuer;
    string public _lockingChainIssue;
    address public _issuingChainDoor;
    address public _issuingChainIssuer;
    string public _issuingChainIssue;

    bool public _isLocking;

    uint256 public _signatureReward;
    uint256 public _minAccountCreateAmount;

    // Analog of XChainCreateClaimID
    function createClaimId(address sender) public virtual payable returns(uint256);

    // Analog of XChainCommit
    function commit(address receiver, uint256 claimId, uint256 amount) public virtual payable;

    // Analog of XChainCommit without address
    function commitWithoutAddress(uint256 claimId, uint256 amount) public virtual payable;

    // Analog of XChainClaim
    function claim(uint256 claimId, uint256 amount, address destination) public virtual;

    // Analog of XChainCreateAccountCommit
    function createAccountCommit(address destination, uint256 amount, uint256 signatureReward) public virtual payable;

    // Analog of XChainAddAttestation
    function addClaimAttestation(uint256 claimId, uint256 amount, address sender, address destination) public virtual;

    // Analog of XChainAddAttestation
    function addCreateAccountAttestation(address destination, uint256 amount, uint256 signatureReward) public virtual;

    // Analog of XChainAddAttestation
    function addAttestation(
        AddClaimAttestationData[] memory claimAttestations,
        AddCreateAccountAttestationData[] memory createAccountAttestations
    ) public virtual;

    function getWitnesses() public virtual view returns (address[] memory);

    function sendTransaction(address payable destination, uint256 value) virtual internal;

    function sendAssets(address destination, uint256 amount) virtual internal;

    // Ownership management functions
    function pause() public onlyOwner whenNotPaused {
        _pause();
    }
    function unpause() public onlyOwner whenPaused {
        _unpause();
    }
    function execute(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation
    ) public onlyOwner returns (bool success) {
        uint256 txGas = type(uint256).max;
        if (operation == Enum.Operation.DelegateCall) {
            // solhint-disable-next-line no-inline-assembly
            assembly {
                success := delegatecall(txGas, to, add(data, 0x20), mload(data), 0, 0)
            }
        } else {
            // solhint-disable-next-line no-inline-assembly
            assembly {
                success := call(txGas, to, value, add(data, 0x20), mload(data), 0, 0)
            }
        }
    }

    /// @dev Fallback function allows to deposit ether.
    receive() external payable {}
}

abstract contract BridgeDoorBase is BridgeDoor {
    using Counters for Counters.Counter;
    Counters.Counter private _claimIds;

    constructor(
        GnosisSafeL2 safe,
        uint256 signatureReward,
        uint256 minAccountCreateAmount,
        address lockingChainDoor,
        address issuingChainDoor
    ) {
        _safe = safe;
        _signatureReward = signatureReward;
        _minAccountCreateAmount = minAccountCreateAmount;
        if (lockingChainDoor == address(0) && issuingChainDoor != address(0)) {
            _isLocking = true;
            _lockingChainDoor = address(this);
            _issuingChainDoor = issuingChainDoor;
        } else if (lockingChainDoor != address(0) && issuingChainDoor == address(0)) {
            _isLocking = false;
            _lockingChainDoor = lockingChainDoor;
            _issuingChainDoor = address(this);
        } else {
            revert("You have to indicate either lockingChainDoor or issuingChainDoor");
        }
        transferOwnership(address(safe));
    }

    /**
     * @dev Throws if called by any account not in the witness list
     */
    modifier onlyWitness() {
        require(_safe.isOwner(msg.sender), "caller is not a witness");
        _;
    }

    // Analog of XChainCreateClaimID
    function createClaimId(address sender) public override payable whenNotPaused returns (uint256) {
        require(msg.value >= _signatureReward, "createClaimId: amount sent is smaller than required signature reward");

        _claimIds.increment();
        uint256 claimId = _claimIds.current();
        claims[claimId].creator = msg.sender;
        claims[claimId].sender = sender;
        claims[claimId].exists = true;

        emit CreateClaim(claimId, msg.sender, sender);

        // Send signature reward to safe
        (bool sent, ) = address(_safe).call{value: msg.value}("");
        require(sent, "Failed to send signature reward to safe vault");

        return claimId;
    }

    // Analog of XChainClaim
    function claim(
        uint256 claimId,
        uint256 amount,
        address destination
    ) public override whenNotPaused {
        address destinationAtt;
        uint256 amountAtt;
        address[] memory witnesses;

        ClaimData storage claimData = claims[claimId];
        require(claimData.exists, "Claim not found");
        require(msg.sender == claimData.creator, "Claim claimer has to be original creator");

        (destinationAtt, amountAtt, witnesses) = checkClaimAttestations(claimId, false);
        require(amountAtt == amount, "claim: attested amount different from claimed amount");

        emit Claim(claimId, msg.sender, amount, destination);

        if (destinationAtt == address(0)) {
            creditClaim(claimId, destination, amount, witnesses);
        }
    }

    // Analog of XChainCreateAccountCommit
    function createAccountCommit(address, uint256, uint256) public virtual override payable whenNotPaused {
        require(_tokenAddress == address(0), "createAccountCommit: cannot create account with a token contract");
    }

    // Analog of XChainAddAttestation
    function addClaimAttestation(
        uint256 claimId,
        uint256 amount,
        address sender,
        address destination
    ) public override onlyWitness whenNotPaused {
        ClaimData storage claimData = claims[claimId];
        require(claimData.exists, "Claim not found");
        require(sender == claimData.sender, "attestClaim: sender does not match");

        claimData.attestations[msg.sender].destination = destination;
        claimData.attestations[msg.sender].amount = amount;

        emit AddClaimAttestation(claimId, msg.sender, amount, destination);

        checkAndCreditClaim(claimId);
    }

    // Analog of XChainAddAttestation
    function addCreateAccountAttestation(address, uint256, uint256) public virtual override onlyWitness whenNotPaused {
        require(_tokenAddress == address(0), "attestCreateAccount: cannot attest account create on token contract");
    }

    function checkAndCreditClaim(uint256 claimId) internal {
        address destination;
        uint256 amount;
        address[] memory witnesses;

        (destination, amount, witnesses) = checkClaimAttestations(claimId, true);
        if (destination == address(0)) {
            // If destination is address(0) do not credit, wait for claim
            return;
        }

        creditClaim(claimId, destination, amount, witnesses);
    }

    function checkClaimAttestations(uint256 claimId, bool justTry) internal view returns(address, uint256, address[] memory) {
        ClaimData storage claimData = claims[claimId];
        require(claimData.exists, "Claim not found");

        address[] memory witnesses = this.getWitnesses();
        uint256 mostHitAmount = 0;
        uint256 mostHitTimes = 0;
        address mostHitDestination = address(0);

        // For every CURRENT witness check it's attestations made
        for (uint256 i = 0; i < witnesses.length; i++) {
            uint256 hitsForThisWitness = 0;
            address witness = witnesses[i];
            AttestationClaimData memory attestation = claimData.attestations[witness];
            // If the witness has not made any attestation then continue
            if (attestation.amount == 0) continue;
            // Check other witnesses having the same attestation
            for (uint256 j = 0; j < witnesses.length; j++) {
                address comparingWitness = witnesses[j];

                AttestationClaimData memory comparingAttestation = claimData.attestations[comparingWitness];
                // Attested the same amount
                if (comparingAttestation.amount == attestation.amount && attestation.destination == comparingAttestation.destination) {
                    hitsForThisWitness++;
                }
            }

            // If is the one with more hits, then is the winning result
            if (hitsForThisWitness > mostHitTimes) {
                mostHitTimes = hitsForThisWitness;
                mostHitAmount = attestation.amount;
                mostHitDestination = attestation.destination;
            }
        }

        // If we are just trying and there's not enough threshold return without throwing exception
        address[] memory witnessHits = new address[](mostHitTimes);
        if (justTry && mostHitTimes < _safe.getThreshold()) {
            return (address(0), 0, witnessHits);
        }

        // When enough attestations, not claimed and valid destination send amount
        require(
            mostHitTimes >= _safe.getThreshold() && mostHitAmount > 0,
            "Can not credit there is no consensus"
        );

        uint256 currentWitnessHitsIndex = 0;
        for (uint256 i = 0; i < witnesses.length; i++) {
            AttestationClaimData memory attestation = claimData.attestations[witnesses[i]];
            if (attestation.amount == mostHitAmount && attestation.destination == mostHitDestination) {
                witnessHits[currentWitnessHitsIndex] = witnesses[i];
                currentWitnessHitsIndex++;
            }
        }

        return (mostHitDestination, mostHitAmount, witnessHits);
    }

    function creditClaim(uint256 claimId, address destination, uint256 amount, address[] memory witnesses) internal {
        delete claims[claimId];
        emit Credit(claimId, destination, amount);

        sendAssets(destination, amount);
        sendWitnessesReward(witnesses);
    }

    function sendWitnessesReward(address[] memory witnesses) internal {
        // Integer division. If witnesses.length no divisable by reward some funds would be lost
        uint256 rewardAmount = _signatureReward / witnesses.length;
        for (uint256 i = 0; i < witnesses.length; i++) {
            sendTransaction(payable(witnesses[i]), rewardAmount);
        }
    }

    function sendTransaction(address payable destination, uint256 value) override internal {
        bool sent = _safe.execTransactionFromModule(destination, value, "", Enum.Operation.Call);
        require(sent, "Failed to send Transaction");
    }

    function getWitnesses() public view override returns (address[] memory) {
        return _safe.getOwners();
    }
}


// File contracts/BridgeDoorNative.sol


pragma solidity ^0.8.0;

contract BridgeDoorNative is BridgeDoorBase {
    constructor(
        GnosisSafeL2 safe,
        uint256 signatureReward,
        uint256 minAccountCreateAmount,
        address issuingChainDoor,
        address lockingChainDoor
    ) BridgeDoorBase(safe, signatureReward, minAccountCreateAmount, lockingChainDoor, issuingChainDoor) {
        require(minAccountCreateAmount > 0, "minAccountCreateAmount must be greater than 0");
        _issuingChainIssue = "XRP";
        _lockingChainIssue = "XRP";
    }

    // Analog of XChainCommit
    function commit(address receiver, uint256 claimId, uint256 amount) public override payable whenNotPaused {
        if (msg.value > 0) {
            require(msg.value >= amount, "Sent amount must be at least equal to amount");
            emit Commit(claimId, msg.sender, amount, receiver);
            (bool sent, ) = address(_safe).call{value: msg.value}("");
            require(sent, "Failed to send commit transaction to safe vault");
        }
    }

    // Analog of XChainCommit without address
    function commitWithoutAddress(uint256 claimId, uint256 amount) public override payable whenNotPaused {
        if (msg.value > 0) {
            require(msg.value >= amount, "Sent amount must be at least equal to amount");
            emit CommitWithoutAddress(claimId, msg.sender, amount);
            (bool sent, ) = address(_safe).call{value: msg.value}("");
            require(sent, "Failed to send commitWithoutAddress transaction to safe vault");
        }
    }

    // Analog of XChainCreateAccountCommit
    function createAccountCommit(
        address destination,
        uint256 amount,
        uint256 signatureReward
    ) public override payable whenNotPaused {
        require(signatureReward >= _signatureReward, "createAccountCommit: amount sent is smaller than required signature reward");
        require(amount >= _minAccountCreateAmount, "createAccountCommit: amount sent is smaller than required minimum account create amount");
        require(msg.value >= signatureReward + amount, "createAccountCommit: not enough balance sent");

        emit CreateAccountCommit(msg.sender, destination, amount, signatureReward);

        (bool sent, ) = address(_safe).call{value: msg.value}("");
        require(sent, "Failed to send createAccountCommit transaction to safe vault");
    }

    // Analog of XChainAddAttestation
    function addCreateAccountAttestation(
        address destination,
        uint256 amount,
        uint256 signatureReward
    ) public override onlyWitness whenNotPaused {
        require(amount >= _minAccountCreateAmount, "attestCreateAccount: insufficient minimum amount sent");

        CreateAccountData storage createAccountDataCheck = createAccounts[destination];
        if (!createAccountDataCheck.exists) {
            createAccounts[destination].signatureReward = signatureReward;
            createAccounts[destination].isCreated = false;
            createAccounts[destination].exists = true;
        }

        CreateAccountData storage createAccountData = createAccounts[destination];

        require(!createAccountData.isCreated, "attestCreateAccount: createAccountData is already created");

        createAccountData.attestations[msg.sender] = amount;

        emit AddCreateAccountAttestation(msg.sender, destination, amount);

        address[] memory witnesses = this.getWitnesses();
        uint256 mostHitAmount = 0;
        uint256 mostHitTimes = 0;

        // For every CURRENT witness check it's attestations made
        for (uint256 i = 0; i < witnesses.length; i++) {
            uint256 hitsForThisWitness = 0;
            address witness = witnesses[i];
            uint256 amountWitnessed = createAccountData.attestations[witness];
            // If the witness has not made any attestation then continue
            if (amountWitnessed == 0) continue;
            // Check other witnesses having the same attestation
            for (uint256 j = 0; j < witnesses.length; j++) {
                address comparingWitness = witnesses[j];

                uint256 comparingAmountWitnessed = createAccountData.attestations[comparingWitness];
                // Attested the same amount
                if (comparingAmountWitnessed == amountWitnessed) hitsForThisWitness++;
            }

            // If is the one with more hits, then is the winning result
            if (hitsForThisWitness > mostHitTimes) {
                mostHitTimes = hitsForThisWitness;
                mostHitAmount = amountWitnessed;
            }
        }

        // When enough attestations, not claimed and valid destination send amount
        if (mostHitTimes >= _safe.getThreshold() && mostHitAmount > 0) {
            address[] memory witnessHits = new address[](mostHitTimes);
            uint256 currentWitnessHitsIndex = 0;
            for (uint256 i = 0; i < witnesses.length; i++) {
                uint256 amountWitnessed = createAccountData.attestations[witnesses[i]];
                if (amountWitnessed == mostHitAmount) {
                    witnessHits[currentWitnessHitsIndex] = witnesses[i];
                    currentWitnessHitsIndex++;
                }
            }

            createAccountData.isCreated = true;
            createAccount(payable(destination), mostHitAmount, witnessHits);
        }
    }

    // Analog of XChainAddAttestation
    function addAttestation(
        AddClaimAttestationData[] memory claimAttestations,
        AddCreateAccountAttestationData[] memory createAccountAttestations
    ) public override onlyWitness whenNotPaused {
        for (uint256 i = 0; i < claimAttestations.length; i++) {
            addClaimAttestation(
                claimAttestations[i].claimId,
                claimAttestations[i].amount,
                claimAttestations[i].sender,
                claimAttestations[i].destination
            );
        }
        for (uint256 i = 0; i < createAccountAttestations.length; i++) {
            addCreateAccountAttestation(
                createAccountAttestations[i].destination,
                createAccountAttestations[i].amount,
                createAccountAttestations[i].signatureReward
            );
        }
    }

    function sendAssets(address destination, uint256 amount) override internal {
        sendTransaction(payable(destination), amount);
    }

    function createAccount(
        address payable destination,
        uint256 value,
        address[] memory witnesses
    ) private {
        emit CreateAccount(destination, value);
        sendTransaction(destination, value);
        sendWitnessesReward(witnesses);
    }
}
        