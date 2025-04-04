// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

interface IMint {
    function mint(address to, uint256 amount) external;
}
contract PointToToken is Ownable {
    using ECDSA for bytes32;

    address public treasury;
    address public token;
    uint256 public fee;
    uint256 public userDailyClaimLimit;
    uint256 public globalDailyClaimLimit;
    uint256 public signatureValidDuration;
    uint256 public manualApproveThreshold;
    uint256 public minClaimAmount;

    mapping(address => mapping(uint256 => uint256)) public userDailyClaimed;
    mapping(uint256 => uint256) public globalDailyClaimed;
    mapping(bytes => bool) public usedSignatures;
    mapping(address => bool) public gameSigner;
    mapping(address => bool) public manualAdmin;
    mapping(address => uint256) public lastNonce;

    event SetTreasury(address treasury);
    event SetConfig(uint256 fee, uint256 userDailyClaimLimit, uint256 globalDailyClaimLimit, uint256 signatureValidDuration, uint256 manualApproveThreshold, uint256 minClaimAmount);
    event SetGameSigner(address gameSigner, bool status);
    event SetManualAdmin(address manualAdmin, bool status);
    event PointConverted(address user, uint256 amount, uint256 nonce);
    event ManualApproval(address user, uint256 amount);

    constructor(address _treasury, address _token, uint256 _fee) {
        require(_fee < 100,"Fee must not exceed 100%");
        treasury = _treasury;
        fee = _fee;
        token = _token;
    }

    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "treasury wrong");
        treasury = _treasury;
        emit SetTreasury(treasury);
    }

    function setConfig(uint256 _fee, uint256 _userDailyClaimLimit, uint256 _globalDailyClaimLimit, uint256 _signatureValidDuration, uint256 _manualApproveThreshold, uint256 _minClaimAmount) external onlyOwner {
        require(_fee < 100,"Fee must not exceed 100%");
        if(_fee > 0) fee = _fee;
        if(_userDailyClaimLimit > 0) userDailyClaimLimit = _userDailyClaimLimit;
        if(_globalDailyClaimLimit > 0) globalDailyClaimLimit = _globalDailyClaimLimit;
        if(_signatureValidDuration > 0) signatureValidDuration = _signatureValidDuration;
        if(_manualApproveThreshold > 0) manualApproveThreshold = _manualApproveThreshold;
        if(_minClaimAmount > 0) minClaimAmount = _minClaimAmount;
        emit SetConfig(fee, userDailyClaimLimit, globalDailyClaimLimit, signatureValidDuration, _manualApproveThreshold, _minClaimAmount);
    }

    function setGameSigner(address _gameSigner, bool status) external onlyOwner {
        require(_gameSigner != address(0), "gameSigner wrong");
        gameSigner[_gameSigner] = status;
        emit SetGameSigner(_gameSigner, status);
    }

    function setManualAdmin(address _manualAdmin, bool status) external onlyOwner {
        require(_manualAdmin != address(0), "manualAdmin wrong");
        manualAdmin[_manualAdmin] = status;
        emit SetManualAdmin(_manualAdmin, status);
    }
  
    function claim(
        uint256 amount, 
        uint256 timestamp,
        uint256 nonce,
        bytes calldata signature
    ) external {
        require(amount > minClaimAmount, "Invalid amount");
        require(nonce > lastNonce[msg.sender], "Nonce already used");
        require(block.timestamp <= timestamp + signatureValidDuration, "Signature expired");

        bytes32 hash = keccak256(abi.encodePacked(msg.sender, amount, timestamp, nonce));
        bytes32 ethSignedMessageHash = hash.toEthSignedMessageHash();

        require(!usedSignatures[signature], "Signature already used");
        require(gameSigner[ethSignedMessageHash.recover(signature)], "Invalid signature");

        usedSignatures[signature] = true;
        lastNonce[msg.sender] = nonce;

        uint256 currentDay = getCurrentDay();
        userDailyClaimed[msg.sender][currentDay] += amount;
        globalDailyClaimed[currentDay] += amount;
        require(userDailyClaimed[msg.sender][currentDay] <= userDailyClaimLimit, "Withdrawal amount exceeds your daily limit");
        require(globalDailyClaimed[currentDay] <= globalDailyClaimLimit, "Total daily withdrawal limit reached");

        _transferToken(msg.sender, amount);
        emit PointConverted(msg.sender, amount, nonce);
    }

    function manualApprove(address user, uint256 amount, bytes calldata signature) external {
        require(manualAdmin[msg.sender], "Only manual admin can approve");
        require(amount > manualApproveThreshold, "Invalid amount");

        bytes32 hash = keccak256(abi.encodePacked(user, amount));
        bytes32 ethSignedMessageHash = hash.toEthSignedMessageHash();

        require(!usedSignatures[signature], "Signature already used");
        require(gameSigner[ethSignedMessageHash.recover(signature)], "Invalid signature");

        usedSignatures[signature] = true;

        uint256 currentDay = getCurrentDay();
        userDailyClaimed[user][currentDay] += amount;
        globalDailyClaimed[currentDay] += amount;
        require(userDailyClaimed[user][currentDay] <= userDailyClaimLimit, "Withdrawal amount exceeds your daily limit");
        require(globalDailyClaimed[currentDay] <= globalDailyClaimLimit, "Total daily withdrawal limit reached");

        _transferToken(user, amount);
        emit ManualApproval(user, amount);
    }

    function _transferToken(address user, uint256 amount) internal {
        uint256 amountFee = amount * fee / 100;
        uint256 amountTransfer = amount - amountFee;
        if(amountFee > 0) IMint(token).mint(treasury, amountFee);
        if(amountTransfer > 0) IMint(token).mint(user, amountTransfer);
    }

    function getCurrentDay() public view returns (uint256) {
        return block.timestamp / 1 days;
    }

    function getManualHash(
        address user,
        uint256 amount
    ) public view returns (bytes32) {
        return 
             keccak256(
                abi.encodePacked(
                    user,
                    amount
                )
            );
    }

    function getClaimHash(
        address user,
        uint256 amount,
        uint256 blockTime,
        uint256 nonce
    ) public view returns (bytes32) {
        return 
             keccak256(
                abi.encodePacked(
                    user,
                    amount,
                    blockTime,
                    nonce
                )
            );
    }
}
