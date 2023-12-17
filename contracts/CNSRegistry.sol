/* SPDX-License-Identifier: UNLICENSED */

pragma solidity ^0.8.0;

/* Importing OpenZeppelin Contracts for utilities and ERC721 functionality */
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "hardhat/console.sol"; /* Importing for console logging during debugging */

/* Contract inheriting from ERC721, ERC721Enumerable, and ERC721URIStorage */
contract CNSRegistry is ERC721, ERC721Enumerable, ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    /* Struct to store NFT metadata */
    struct CName {
        address owner;
        bool listed;
        uint256 price;
        uint256 sold;
        address[] favorites;
    }

    /* Mappings to keep track of NFT data */
    mapping(uint256 => CName) public CNames; /* Keep track of NFT metadata */
    mapping(string => address) public registeredNames; /* Map registered names to owners */
    mapping(uint256 => address) public favorited; /* Keep track of users who favorited an NFT */
    mapping(address => string) public imageToAddress; /* Map user addresses to avicons */

    /* Event emitted upon successful NFT registration */
    event Registered(address indexed who, string name);
    /* Event emitted when an NFT is listed for sale */
    event NFTListed(uint256 indexed tokenId, address indexed seller, uint256 price);

    /* SVG code for NFT representation */
    string svgPartOne = "<svg xmlns='http://www.w3.org/2000/svg' preserveAspectRatio='xMinYMin meet' viewBox='0 0 350 350'><style>.base { fill: white; font-family: serif; font-size: 24px; }</style><rect width='100%' height='100%' fill='";
    string svgPartTwo = "'/><text x='50%' y='50%' class='base' dominant-baseline='middle' text-anchor='middle'>";

    /* Constructor initializing the name and symbol of the ERC721 contract */
    constructor() ERC721("ENSRegistry", "ENSR") {}

    /**
     * @dev Function to reserve CNS names
     * @param _name The name to be reserved
     * @param _bgColor The background color for the SVG representation
     */
    function reserveName(string memory _name, string memory _bgColor) public {
        /* Check if the name is not an empty string */
        require(bytes(_name).length > 0, "Name cannot be empty");

        /* Validate _bgColor to ensure it's a valid color format (you may need to customize this validation) */
        require(validateColor(_bgColor), "Invalid color format");

        /* Check if the name is still available */
        require(registeredNames[_name] == address(0), "Name Already taken");

        /* Reconstruct the SVG to include the name and bg color */
        string memory finalSvg = string(abi.encodePacked(svgPartOne, _bgColor, svgPartTwo, _name, "</text></svg>"));

        /* Autofill the .celo extension to the input name */
        string memory name = string(abi.encodePacked(_name, ".celo"));

        /* Get JSON metadata and base64 encode it */
        string memory json = Base64.encode(bytes(string(abi.encodePacked('{"name": "', name, '", "description": "Your Unique identity on the celo Blockchain.", "image": "data:image/svg+xml;base64,', Base64.encode(bytes(finalSvg)), '"}'))));

        /* Prepend data:application/json;base64, to the data */
        string memory finalTokenUri = string(abi.encodePacked("data:application/json;base64,", json));

        /* Mint the NFT to the sender */
        uint256 newTokenId = _tokenIds.current();
        _safeMint(msg.sender, newTokenId);

        /* Update URI to be consistent with JSON files */
        _setTokenURI(newTokenId, finalTokenUri);

        /* Update the struct */
        CName storage newCName = CNames[newTokenId];
        newCName.owner = msg.sender;
        newCName.listed = false;
        newCName.price = 0;
        newCName.sold = 0;
        registeredNames[_name] = msg.sender;

        /* Increment the counter for the next NFT */
        _tokenIds.increment();

        /* Emit the event */
        emit Registered(msg.sender, _name);
    }

    /**
     * @dev Function to validate the color format
     * @param _color The color code to be validated
     * @return bool indicating whether the color format is valid or not
     */
    function validateColor(string memory _color) internal pure returns (bool) {
        /* Implement your own logic to validate the color format */
        /* For simplicity, check if the string length is 7 (hex color code length) */
        return bytes(_color).length == 7;
    }

    /**
     * @dev Function to list the NFTs for sale
     * @param _tokenId The ID of the NFT to be listed for sale
     * @param _price The price at which the NFT is listed for sale
     */
    function sell(uint256 _tokenId, uint256 _price) public {
        require(CNames[_tokenId].owner == msg.sender, "Only NFT owner can list Item");
        require(_price > 0, "Price should be greater than zero");

        /* Update the struct */
        CName storage editCName = CNames[_tokenId];
        editCName.listed = true;
        editCName.price = _price;

        /* Emit the event to track the NFT listing */
        emit NFTListed(_tokenId, msg.sender, _price);
    }

    /**
     * @dev Function to buy an NFT and transfer ownership
     * @param _tokenId The ID of the NFT to be purchased
     */
    function buyNFT(uint256 _tokenId) public payable {
        /* Check if the NFT exists */
        require(_exists(_tokenId), "NFT does not exist");
        require(CNames[_tokenId].owner != msg.sender, "Owner cannot buy own item");
        require(CNames[_tokenId].listed == true, "NFT not listed");
        require(CNames[_tokenId].price <= msg.value, "Insufficient funds to purchase item");

        /* Pay for the NFT */
        (bool success, ) = payable(CNames[_tokenId].owner).call{value: msg.value}("");
        if (success) {
            /* Transfer the NFT */
            _transfer(CNames[_tokenId].owner, msg.sender, _tokenId);

            /* Update the struct */
            CName storage buyCName = CNames[_tokenId];
            buyCName.owner = msg.sender;
            buyCName.listed = false;
            buyCName.sold += 1;
        }
    }

    /**
     * @dev Function to fetch NFT metadata
     * @param _tokenId The ID of the NFT to fetch metadata for
     * @return Tuple containing NFT metadata (owner, listed, price, sold, favorites)
     */
    function getNft(uint256 _tokenId)
        public
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
        return (rCName.owner, rCName.listed, rCName.price, rCName.sold, rCName.favorites);
    }
    
    /**
     * @dev Function to like NFTs
     * @param _tokenId The ID of the NFT to be liked
     */
    function likeNft(uint256 _tokenId) public {
        require(favorited[_tokenId] != msg.sender, "NFT already favorited");
        CName storage likeCName = CNames[_tokenId];
        likeCName.favorites.push(msg.sender);
        favorited[_tokenId] = msg.sender;
    }

    /**
     * @dev Function to update the struct with the image of the users
     * @param _imageUri The URI of the image/avicon for the user
     */
    function setAddressAvicon(string memory _imageUri) public {
        imageToAddress[msg.sender] = _imageUri;
    }

    /**
     * @dev Function to query the mapping for the user's imageUri/avicon
     * @param _address The address of the user to query the imageUri/avicon for
     * @return The URI of the image/avicon for the user
     */
    function getAddressAvicon(address _address)
        public
        view
        returns (string memory)
    {
        string memory _imageUri = imageToAddress[_address];
        return _imageUri;
    }

    /* The following functions are overrides required by Solidity. */

    /**
     * @dev Function to perform actions before token transfer
     * @param from The address transferring the token
     * @param to The address receiving the token
     * @param tokenId The ID of the token being transferred
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    /**
     * @dev Function to burn an NFT
     * @param tokenId The ID of the NFT to be burned
     */
    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }

    /**
     * @dev Function to get the URI of the token
     * @param tokenId The ID of the token to get the URI for
     * @return The URI of the token
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    /**
     * @dev Function to check if an interface is supported
     * @param interfaceId The ID of the interface to check for support
     * @return bool indicating whether the interface is supported or not
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
