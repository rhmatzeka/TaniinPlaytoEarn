// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract TaniinCoin is ERC20, Ownable {
    constructor(address owner) ERC20("Taniin Coin", "TANI") Ownable(owner) {}

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}

contract TaniinLand is ERC721URIStorage, Ownable {
    uint256 public constant LAND_PRICE_WEI = 0.001 ether;
    uint256 public nextLandId = 1;
    mapping(uint256 => bool) public planted;

    event LandPurchased(address indexed player, uint256 indexed landId);
    event SeedPlanted(address indexed player, uint256 indexed landId);
    event LandHarvested(address indexed player, uint256 indexed landId, uint256 cropAmount);

    constructor(address owner) ERC721("Taniin Land", "TLAND") Ownable(owner) {}

    function buyLand(string calldata tokenUri) external payable returns (uint256 landId) {
        require(msg.value >= LAND_PRICE_WEI, "LAND_PRICE_NOT_MET");
        landId = nextLandId++;
        _safeMint(msg.sender, landId);
        _setTokenURI(landId, tokenUri);
        emit LandPurchased(msg.sender, landId);
    }

    function plant(uint256 landId) external {
        require(ownerOf(landId) == msg.sender, "NOT_LAND_OWNER");
        require(!planted[landId], "ALREADY_PLANTED");
        planted[landId] = true;
        emit SeedPlanted(msg.sender, landId);
    }

    function harvest(uint256 landId) external returns (uint256 cropAmount) {
        require(ownerOf(landId) == msg.sender, "NOT_LAND_OWNER");
        require(planted[landId], "NOT_PLANTED");
        planted[landId] = false;
        cropAmount = 3;
        emit LandHarvested(msg.sender, landId, cropAmount);
    }

    function withdraw(address payable to) external onlyOwner {
        to.transfer(address(this).balance);
    }
}

contract TaniinItems is ERC1155, Ownable {
    uint256 public constant SEED = 1;
    uint256 public constant CROP = 2;

    constructor(address owner, string memory metadataUri) ERC1155(metadataUri) Ownable(owner) {}

    function mint(address to, uint256 id, uint256 amount) external onlyOwner {
        _mint(to, id, amount, "");
    }

    function burn(address from, uint256 id, uint256 amount) external onlyOwner {
        _burn(from, id, amount);
    }
}
