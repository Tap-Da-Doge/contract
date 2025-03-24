// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

contract NFT is ERC721, Ownable {

    string baseURI;
    uint256 public maxLevel;
    mapping(uint256 => uint256) public level;
    mapping(address => bool) public minter;
    mapping(uint256 => string) private _tokenURIs;
    uint256 public currentIndex = 1;

    modifier onlyMinter() {
        require(minter[msg.sender], "Only Minter");
        _;
    }

    constructor(string memory name, string memory symbol, uint256 _maxLevel, string memory _baseUri) ERC721(name, symbol) {
        maxLevel = _maxLevel;
        baseURI = _baseUri;
    }

    event SetMinter(address minter, bool status, uint256 blockTime);
    event SetMaxLevel(uint256 maxLevel);

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string memory _baseUri) public onlyOwner() {
        baseURI = _baseUri;
    }

    function setMaxLevel(uint256 _maxLevel) external onlyOwner() {
        maxLevel = _maxLevel;
        emit SetMaxLevel(_maxLevel);
    }

    function setMinter(address _minter, bool status) external onlyOwner() {
        minter[_minter] = status;
        emit SetMinter(_minter, status, block.timestamp);
    }

    function mint(address to, uint256 _level) public onlyMinter() {
        require(_level > 0 && _level <= maxLevel, "level wrong");
        _safeMint(to, currentIndex);
        level[currentIndex] = _level;
        currentIndex += 1;
    }

    function burn(uint256 tokenId) external {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "Not owner nor approved");
        _burn(tokenId);
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireMinted(tokenId);

        string memory base = _baseURI();

        uint256 _level = level[tokenId];
        return string(abi.encodePacked(base, Strings.toString(_level) , ".json"));
    }
}