// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IMint {
    function mint(address to, uint256 _level) external;
}

contract INO is Ownable {
    using SafeERC20 for IERC20;
    address public nft;
    address public treasury;
    uint256 public priceBNB;
    uint256 private nonce = 0;
    constructor(address _nft, address _treasury, uint256 _priceBNB) {
        nft = _nft;
        treasury = _treasury;
        priceBNB = _priceBNB;
    }

    event SetUri(uint256 level, string uri, uint256 blockTime);
    event SetPrice(uint256 price, string typePrice, uint256 blockTime);
    event SetTreasury(address treasury, uint256 blockTime);
    event Buy(uint256 price, string typeBuy, uint256 blockTime);

    struct Level {
        uint256 maxLevel1;
        uint256 maxLevel2;
        uint256 maxLevel3;
        uint256 maxLevel4;
        uint256 maxLevel5;
        uint256 maxLevel6;
        uint256 maxLevel7;
        uint256 maxLevel8;
        uint256 maxLevel9;
        uint256 maxLevel10;
    }

    Level public level;

    mapping(uint256 => string) public uri; // level to uri

    function setLevel(Level calldata _level) external onlyOwner() {
        level.maxLevel1 = _level.maxLevel1;
        level.maxLevel2 = _level.maxLevel2;
        level.maxLevel3 = _level.maxLevel3;
        level.maxLevel4 = _level.maxLevel4;
        level.maxLevel5 = _level.maxLevel5;
        level.maxLevel6 = _level.maxLevel6;
        level.maxLevel7 = _level.maxLevel7;
        level.maxLevel8 = _level.maxLevel8;
        level.maxLevel9 = _level.maxLevel9;
        level.maxLevel10 = _level.maxLevel10;
    }

    function setPriceBNB(uint256 _price) external onlyOwner() {
        priceBNB = _price;
        emit SetPrice(_price, "bnb", block.timestamp);
    }

    function setTreasury(address _treasury) external onlyOwner() {
        treasury = _treasury;
        emit SetTreasury(_treasury, block.timestamp);
    }

    function buyWithBNB(uint256 amount) external payable {
        uint256 value = amount * priceBNB;
        require(value == msg.value, "Amount Wrong");
        (bool success, ) = payable(treasury).call{value: value}("");
        require(success, "Transfer failed.");
        for(uint256 i =0; i < amount; i++){
            uint256 levelTokenId = randomLevel();
            IMint(nft).mint(msg.sender, levelTokenId);
            emit Buy(priceBNB, "bnb", block.timestamp);
        }
    }

    function randomLevel() internal returns (uint256) {
        nonce++;
        uint256 randomValue = uint256(
            keccak256(
                abi.encodePacked(block.timestamp, block.prevrandao, msg.sender, gasleft(), nonce)
            )
        ) % level.maxLevel10;

        if (randomValue < level.maxLevel1) return 1;
        else if (level.maxLevel1 <= randomValue && randomValue < level.maxLevel2) return 2;
        else if (level.maxLevel2 <= randomValue && randomValue < level.maxLevel3) return 3;
        else if (level.maxLevel3 <= randomValue && randomValue < level.maxLevel4) return 4;
        else if (level.maxLevel4 <= randomValue && randomValue < level.maxLevel5) return 5;
        else if (level.maxLevel5 <= randomValue && randomValue < level.maxLevel6) return 6;
        else if (level.maxLevel6 <= randomValue && randomValue < level.maxLevel7) return 7;
        else if (level.maxLevel7 <= randomValue && randomValue < level.maxLevel8) return 8;
        else if (level.maxLevel8 <= randomValue && randomValue < level.maxLevel9) return 9;
        else if (level.maxLevel9 <= randomValue && randomValue < level.maxLevel10) return 10;
        else return 1;
    } 

}
