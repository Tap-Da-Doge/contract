// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract Staking is Ownable, ERC721Holder {
    address public nft;
    constructor(address _nft) {
        nft = _nft;
    }

    mapping(uint256 => address) public nftOwnerOf;
    mapping(address => uint256) public balanceOf;

    uint256 public totalUsers;
    uint256 public totalStaked;

    event Stake(address indexed user, uint256[] tokenId);
    event Unstake(address indexed user, uint256[] tokenId);
    event SetNft(address nft);

    function setNft(address _nft) external onlyOwner() {
        nft = _nft;
        emit SetNft(_nft);
    }

    function stake(uint256[] memory tokenId) external {
        require(tokenId.length > 0, "LENGTH_WRONG");
        uint256 balanceOfBefore = balanceOf[_msgSender()];
        totalStaked += tokenId.length;

        if (balanceOfBefore == 0) {
            totalUsers++;
        }

        for(uint256 i = 0; i < tokenId.length; i++){
            IERC721(nft).transferFrom(_msgSender(), address(this), tokenId[i]);
            nftOwnerOf[tokenId[i]] = _msgSender();
            balanceOf[_msgSender()] += 1;
        }

        emit Stake(_msgSender(),tokenId);
    }

    function unstake(uint256[] memory tokenId) external {
        require(tokenId.length > 0, "LENGTH_WRONG");
        totalStaked -= tokenId.length;

        for(uint256 i = 0; i < tokenId.length; i++){
            require(nftOwnerOf[tokenId[i]] == _msgSender(), "OWNER_NFT_WRONG");
            delete nftOwnerOf[tokenId[i]];
            balanceOf[_msgSender()] -= 1;
            IERC721(nft).transferFrom(address(this), _msgSender(), tokenId[i]);
        }

        if (balanceOf[_msgSender()] == 0) {
            totalUsers--;
        }

        emit Unstake(_msgSender(), tokenId);
    }

}


