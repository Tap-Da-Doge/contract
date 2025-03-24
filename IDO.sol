// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract IDO is Ownable {

    using SafeERC20 for IERC20;
    address public token;
    uint256 public tokenPrice;
    uint256 public startTime;
    uint256 public endTime;

    uint256 public startRelease;
    uint256 public cliff;
    uint256 public vesting;
    uint256 public tge;

    uint256 public cap;    
    uint256 public purchaseLimit;
    uint256 public total;
    bool public isClaimed = false;

    address public tokenPayment;
    address public treasury;

    mapping (address => uint256) public payAmount;
    mapping (address => uint256) private tokenReleased;
    
    modifier verifyAmount(uint256 amount) {
        require(amount <= purchaseLimit, "Purchase amount exceeds limit");
        require(total + amount <= cap, "Total sale cap exceeded");
        _;
    }
    constructor(uint256 _start, uint256 _end, address _token, uint256 _tokenPrice, uint256 _startRelease, uint256 _cliff, uint256 _vesting, uint256 _tge, uint256 _purchaseLimit, uint256 _cap, address _tokenPayment, address _treasury) {
        startTime = _start;
        endTime = _end;
        token = _token;
        tokenPrice = _tokenPrice;
        startRelease = _startRelease;
        cliff = _cliff;
        vesting = _vesting;
        tge = _tge;
        purchaseLimit = _purchaseLimit;
        tokenPayment = _tokenPayment;
        treasury = _treasury;
        cap = _cap;
    }

    event SetPrice(uint256 price, uint256 blockTime);
    event SetTime(uint256 startTime, uint256 endTime, uint256 blockTime);
    event SetCap(uint256 cap, uint256 blockTime);
    event SetClaim(bool status, uint256 blockTime);
    event SetPurchaseLimit(uint256 limit, uint256 blockTime);
    event SetToken(address token, uint256 blockTime);
    event SetAdmin(address admin, bool status, uint blockTime);
    event Buy(address user, uint256 amount, uint256 total, uint256 blockTime);
    event Released(address user, uint256 amount, uint256 blockTime);
    event SetVesting(uint256 startRelease, uint256 cliff, uint256 vesting, uint256 tge);
    event SetIDO(uint256 start, uint256 end, uint256 price, uint256 limit, uint256 cap);

    function setVesting(uint256 _startRelease, uint256 _cliff, uint256 _vesting, uint256 _tge) external onlyOwner() {
        require(_tge <= 100, "TGE_WRONG");
        if(_startRelease > 0) startRelease = _startRelease;
        if(_cliff > 0) cliff = _cliff;
        if(_vesting > 0) vesting = _vesting;
        if(_tge > 0) tge = _tge;
        emit SetVesting(startRelease, cliff, vesting, tge);
    }

    function setIDO(uint256 _start, uint256 _end, uint256 _price, uint256 _purchaseLimit, uint256 _cap) external onlyOwner() {
        if(_start > 0) startTime = _start;
        if(_end > 0) endTime = _end;
        if(_price > 0) tokenPrice = _price;
        if(_purchaseLimit > 0) purchaseLimit = _purchaseLimit;
        if(_cap > 0) cap = _cap;
        emit SetIDO(startTime, endTime, tokenPrice, purchaseLimit, cap);
    }

    function setTokenPayment(address _tokenPayment) external onlyOwner() {
        tokenPayment = _tokenPayment;
    }

    function setTreasury(address _treasury) external onlyOwner() {
        treasury = _treasury;
    } 

    function setClaim(bool status) external onlyOwner {
        isClaimed = status;
        emit SetClaim(status, block.timestamp);
    }

    function setToken(address _token) external onlyOwner {
        token = _token;
        emit SetToken(_token, block.timestamp);
    }

    function withdrawEther() external onlyOwner {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }

    function withdrawToken(address _token) external onlyOwner {
        uint256 amount = IERC20(_token).balanceOf(address(this));
        IERC20(_token).safeTransfer(msg.sender, amount);
    }

    function buy(uint256 amount) external verifyAmount(amount) {
        require(block.timestamp > startTime && block.timestamp < endTime, "IDO: TIME_WRONG");
        IERC20(tokenPayment).safeTransferFrom(msg.sender, treasury, amount);
        payAmount[msg.sender] += amount;
        total += amount;
        emit Buy(msg.sender, amount, total, block.timestamp);
    }

    function released(address _user) public view returns(uint256){
        return tokenReleased[_user];
    }

    function releasable(address _user) public view returns(uint256){
        uint256 amount;
        if(isClaimed){
            uint256 totalAllocation = payAmount[_user] * 1e18 / tokenPrice;
            amount = _vestingSchedule(totalAllocation, block.timestamp);
        }else{
            amount = 0;
        }
        return amount - released(_user);
    }

    function release() external {
        require(isClaimed, "IDO: IS_CLAIMED_WRONG");
        uint256 amount = releasable(msg.sender);
        require(amount > 0, "IDO: AMOUNT=0");
        tokenReleased[msg.sender] += amount;
        IERC20(token).safeTransfer(msg.sender, amount);
        emit Released(msg.sender, amount, block.timestamp);
    }

    function _vestingSchedule(uint256 totalAllocation, uint256 timestamp) internal view returns(uint256){
        if(timestamp < startRelease){
            return 0;
        } else if (timestamp > (startRelease + cliff + vesting)){
            return totalAllocation;
        } else {
            uint256 tokenTge = totalAllocation * tge / 100;
            uint256 tokenVesting = 0;
            if(timestamp > (startRelease + cliff)){
                tokenVesting = (totalAllocation - tokenTge) * (timestamp - startRelease - cliff) / vesting;
            }
            return tokenTge + tokenVesting;
        }
    }   

}
