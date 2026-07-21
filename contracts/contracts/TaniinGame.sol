// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract TaniinCoin is ERC20, Ownable {
    event GameSpend(address indexed player, uint256 amount);

    constructor(address owner) ERC20("Taniin Coin", "TANI") Ownable(owner) {}

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function gameSpend(address from, uint256 amount) external onlyOwner {
        require(from != address(0), "INVALID_PLAYER");
        _burn(from, amount);
        emit GameSpend(from, amount);
    }
}

contract TaniinLand is ERC721URIStorage, Ownable {
    uint256 public constant LAND_PRICE_WEI = 0.001 ether;
    uint256 public constant LAND_SELL_PRICE_WEI = 0.0007 ether;
    uint256 public nextLandId = 1;
    mapping(uint256 => bool) public planted;
    mapping(address => mapping(uint256 => uint256)) public playerPlotLandId;
    mapping(uint256 => address) public landPlayer;
    mapping(uint256 => uint256) public landPlotId;

    event LandPurchased(address indexed player, uint256 indexed landId);
    event LandSold(address indexed player, uint256 indexed landId, uint256 refundWei);
    event SeedPlanted(address indexed player, uint256 indexed landId);
    event LandHarvested(address indexed player, uint256 indexed landId, uint256 cropAmount);
    event PlayerLandMinted(address indexed player, uint256 indexed plotId, uint256 indexed landId);
    event PlayerLandSold(address indexed player, uint256 indexed plotId, uint256 indexed landId);
    event PlayerSeedPlanted(address indexed player, uint256 indexed plotId, uint256 indexed landId);
    event PlayerLandHarvested(address indexed player, uint256 indexed plotId, uint256 indexed landId, uint256 cropAmount);

    constructor(address owner) ERC721("Taniin Land", "TLAND") Ownable(owner) {}

    function buyLand(string calldata tokenUri) external payable returns (uint256 landId) {
        require(msg.value >= LAND_PRICE_WEI, "LAND_PRICE_NOT_MET");
        landId = nextLandId++;
        _safeMint(msg.sender, landId);
        _setTokenURI(landId, tokenUri);
        emit LandPurchased(msg.sender, landId);
    }

    function sellLand(uint256 landId) external {
        require(ownerOf(landId) == msg.sender, "NOT_LAND_OWNER");
        require(!planted[landId], "LAND_PLANTED");
        require(address(this).balance >= LAND_SELL_PRICE_WEI, "INSUFFICIENT_CONTRACT_BALANCE");

        uint256 plotId = landPlotId[landId];
        if (plotId != 0 && landPlayer[landId] == msg.sender) {
            delete playerPlotLandId[msg.sender][plotId];
            delete landPlayer[landId];
            delete landPlotId[landId];
        }

        delete planted[landId];
        _burn(landId);

        (bool sent, ) = payable(msg.sender).call{value: LAND_SELL_PRICE_WEI}("");
        require(sent, "SELL_REFUND_FAILED");
        emit LandSold(msg.sender, landId, LAND_SELL_PRICE_WEI);
    }

    function mintLandFor(address player, uint256 plotId, string calldata tokenUri) external onlyOwner returns (uint256 landId) {
        landId = _mintLandFor(player, plotId, tokenUri);
    }

    function sellLandFor(address player, uint256 plotId, string calldata tokenUri) external onlyOwner returns (uint256 landId) {
        tokenUri;
        landId = _requirePlayerPlot(player, plotId);
        require(!planted[landId], "LAND_PLANTED");

        delete planted[landId];
        delete playerPlotLandId[player][plotId];
        delete landPlayer[landId];
        delete landPlotId[landId];

        _burn(landId);
        emit PlayerLandSold(player, plotId, landId);
    }

    function plantFor(address player, uint256 plotId, string calldata tokenUri) external onlyOwner returns (uint256 landId) {
        landId = _ensurePlayerPlot(player, plotId, tokenUri);
        require(!planted[landId], "ALREADY_PLANTED");
        planted[landId] = true;
        emit SeedPlanted(player, landId);
        emit PlayerSeedPlanted(player, plotId, landId);
    }

    function harvestFor(address player, uint256 plotId, string calldata tokenUri) external onlyOwner returns (uint256 landId, uint256 cropAmount) {
        tokenUri;
        landId = _requirePlayerPlot(player, plotId);
        require(planted[landId], "NOT_PLANTED");
        planted[landId] = false;
        cropAmount = 3;
        emit LandHarvested(player, landId, cropAmount);
        emit PlayerLandHarvested(player, plotId, landId, cropAmount);
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

    function _requirePlayerPlot(address player, uint256 plotId) internal view returns (uint256 landId) {
        require(player != address(0), "INVALID_PLAYER");
        require(plotId > 0, "INVALID_PLOT");
        landId = playerPlotLandId[player][plotId];
        require(landId != 0, "PLOT_NOT_MINTED");
        require(_ownerOf(landId) == player, "NOT_LAND_OWNER");
    }

    function _ensurePlayerPlot(address player, uint256 plotId, string calldata tokenUri) internal returns (uint256 landId) {
        require(player != address(0), "INVALID_PLAYER");
        require(plotId > 0, "INVALID_PLOT");
        landId = playerPlotLandId[player][plotId];
        if (landId == 0) {
            return _mintLandFor(player, plotId, tokenUri);
        }
        require(_ownerOf(landId) == player, "NOT_LAND_OWNER");
    }

    function _mintLandFor(address player, uint256 plotId, string calldata tokenUri) internal returns (uint256 landId) {
        require(player != address(0), "INVALID_PLAYER");
        require(plotId > 0, "INVALID_PLOT");
        require(playerPlotLandId[player][plotId] == 0, "PLOT_ALREADY_MINTED");

        landId = nextLandId++;
        playerPlotLandId[player][plotId] = landId;
        landPlayer[landId] = player;
        landPlotId[landId] = plotId;

        _safeMint(player, landId);
        _setTokenURI(landId, tokenUri);
        emit LandPurchased(player, landId);
        emit PlayerLandMinted(player, plotId, landId);
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
