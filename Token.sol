// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IDEXRouter {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
}


interface IDEXFactory {
    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);
}

contract Token is ERC20, Ownable {
    uint256 public buyFee;
    uint256 public sellFee;
    uint256 public feeEndTime;
    uint256 public constant FEE_DENOMINATOR = 1000;
    uint256 public maxSupply;
    mapping(address => bool) public pair;
    mapping(address => bool) public minter;
    mapping(address => bool) private _isExcludedFromFee;

    modifier onlyMinter() {
        require(minter[_msgSender()], "Only Minter");
        _;
    }

    event SetFees(uint256 buyFee, uint256 sellFee);

    constructor(string memory name, string memory symbol, uint256 _buyFee, uint256 _sellFee, uint256 _maxSupply, uint256 initialSupply, uint256 _feeEndTime, address _router) ERC20(name, symbol) {
        _isExcludedFromFee[msg.sender] = true;
        buyFee = _buyFee;
        sellFee = _sellFee;
        maxSupply = _maxSupply;
        feeEndTime = _feeEndTime;
        IDEXRouter router = IDEXRouter(_router);
        address _pair = IDEXFactory(router.factory()).createPair(router.WETH(), address(this));
        pair[_pair] = true;
        _mint(msg.sender, initialSupply);
    }

    function setMiner(address _minter, bool status) external onlyOwner {
        minter[_minter] = status;
    }

    function setPair(address _pair, bool status) external onlyOwner {
        pair[_pair] = status;
    }

    function setFeeEndTime(uint256 _feeEndTime) external onlyOwner {
        feeEndTime = _feeEndTime;
    }

    function setBuySellFee(uint256 _buyFee, uint256 _sellFee) external onlyOwner {
        require(_buyFee <= 20 && _sellFee <= 20, "Max fee is 20%");
        buyFee = _buyFee;
        sellFee = _sellFee;
        emit SetFees(_buyFee, _sellFee);
    }

    function mint(address to, uint256 amount) external onlyMinter {
        require(totalSupply() + amount <= maxSupply, "Exceeds max supply");
        _mint(to, amount);
    }

    function _transfer(address sender, address recipient, uint256 amount) internal override {
        uint256 feeAmount = 0;

        if (!_isExcludedFromFee[sender] && !_isExcludedFromFee[recipient]) {
            if (block.timestamp <= feeEndTime) {
                if (pair[sender]) {
                    feeAmount = (amount * buyFee) / FEE_DENOMINATOR;
                } else if (pair[recipient]) {
                    feeAmount = (amount * sellFee) / FEE_DENOMINATOR;
                }
            }
        }

        if (feeAmount > 0) {
            super._transfer(sender, address(this), feeAmount);
            amount -= feeAmount;
        }

        super._transfer(sender, recipient, amount);
    }

    function excludeFromFee(address account, bool excluded) external onlyOwner {
        _isExcludedFromFee[account] = excluded;
    }

    function withdrawFees() external onlyOwner {
        uint256 balance = balanceOf(address(this));
        require(balance > 0, "No fees to withdraw");
        super._transfer(address(this), owner(), balance);
    }
}
