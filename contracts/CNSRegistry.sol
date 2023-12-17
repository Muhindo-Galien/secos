// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

contract CNSRegistry is Ownable, ERC721, ERC721Enumerable, ERC721URIStorage {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;
    
    struct CName {
        address owner;
        bool listed;
        uint256 price;
        uint256 sold;
        address[] favorites;
    }

    mapping(uint256 => CName) public CNames;
    mapping(string => address) public registeredNames;
    mapping(uint256 => address) public favorited;
    mapping(address => string) public imageToAddress;

    event Registered(address indexed who, string name);

    // SVG parts for generating token images
    string private svgPartOne =
        "<svg xmlns='http://www.w3.org/2000/svg' preserveAspectRatio='xMinYMin meet' viewBox='0 0 350 350'><style>.base { fill: white; font-family: serif; font-size: 24px; }</style><rect width='100%' height='100%' fill='";
    string private svgPartTwo =
        "'/><text x='50%' y='50%' class='base' dominant-baseline='middle' text-anchor='middle'>";

    // Contract initialization
    constructor() ERC721("ENSRegistry", "ENSR") {}

    // Function to reserve a name
    function reserveName(string memory _name, string memory _bgColor) external onlyOwner {
        // Ensure the name is available
        bytes32 nameHash = keccak256(abi.encodePacked(_name));
        require(registeredNames[_name] == address(0), "Name Already taken");

        // Generate SVG for the token
        string memory finalSvg = string(
            abi.encodePacked(svgPartOne, _bgColor, svgPartTwo, _name, "</text></svg>")
        );

        // Add '.celo' to the name and create JSON metadata
        string memory name = string(abi.encodePacked(_name, ".celo"));
        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "',
                        name,
                        '", "description": "Your Unique identity on the celo Blockchain.", "image": "data:image/svg+xml;base64,',
                        Base64.encode(bytes(finalSvg)),
                        '"}'
                    )
                )
            )
        );

        // Combine metadata with prefix and set as token URI
        string memory finalTokenUri = string(abi.encodePacked("data:application/json;base64,", json));

        // Mint the NFT
        uint256 newTokenId = _tokenIds.current();
        _safeMint(owner(), newTokenId);
        _setTokenURI(newTokenId, finalTokenUri);

        // Update storage and emit event
        CName storage newCName = CNames[newTokenId];
        newCName.owner = owner();
        newCName.listed = false;
        newCName.price = 0;
        newCName.sold = 0;
        registeredNames[_name] = owner();
        
        _tokenIds.increment();
        emit Registered(owner(), _name);
    }

    // Function to list an NFT for sale
    function sell(uint256 _tokenId, uint256 _price) external onlyOwner {
        require(CNames[_tokenId].owner == owner(), "Only NFT owner can list Item");
        require(_price > 0, "Price should be greater than zero");

        // Update the struct
        CName storage editCName = CNames[_tokenId];
        editCName.listed = true;
        editCName.price = _price;
    }

    // Function to buy an NFT
    function buyNFT(uint256 _tokenId) external payable {
        require(CNames[_tokenId].owner != msg.sender, "Owner can not buy own item");
        require(CNames[_tokenId].listed == true, "NFT not listed");
        require(CNames[_tokenId].price <= msg.value, "Insufficient funds to purchase item");

        // Transfer payment to the owner
        (bool success, ) = payable(CNames[_tokenId].owner).call{value: msg.value}("");
        require(success, "Payment failed");
        
        // Transfer NFT ownership
        _transfer(CNames[_tokenId].owner, msg.sender, _tokenId);

        // Update the struct
        CName storage buyCName = CNames[_tokenId];
        buyCName.owner = msg.sender;
        buyCName.listed = false;
        buyCName.sold += 1;
    }

    // Function to fetch NFT information
    function getNft(uint256 _tokenId)
        external
        view
        returns (
            address,
            bool,
            uint256,
            uint256,
            address[] memory
        )
    {
        CName storage rCName = CNames[_tokenId];
        return (
            rCName.owner,
            rCName.listed,
            rCName.price,
            rCName.sold,
            rCName.favorites
        );
    }

    // Function to like an NFT
    function likeNft(uint256 _tokenId) external {
        require(favorited[_tokenId] != msg.sender, "NFT already favorited");
        CName storage likeCName = CNames[_tokenId];
        likeCName.favorites.push(msg.sender);
        favorited[_tokenId] = msg.sender;
    }

    // Function to update the struct with the image of the users
    function setAddressAvicon(string memory _imageUri) external {
        imageToAddress[msg.sender] = _imageUri;
    }

    // Function to query the mapping for the users' imageUri/avicon
    function getAddressAvicon(address _address) external view returns (string memory) {
        return imageToAddress[_address];
    }

    // Overrides and additional functions

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId) external view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
