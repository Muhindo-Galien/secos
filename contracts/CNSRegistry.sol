//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;



import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "hardhat/console.sol";



contract CNSRegistry is ERC721, ERC721Enumerable, ERC721URIStorage {

    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;



    struct CName {

        bool listed;

        uint256 price;

        uint256 sold;

        address[] favorites;

    }



    mapping(uint256 => CName) public CNames;

    mapping(string => address) public registeredNames;

    mapping(uint256 => address[]) public favorited;

    mapping(address => string) public imageToAddress;



    event Registered(address indexed who, string name);



    string svgPartOne =

        "<svg xmlns='http://www.w3.org/2000/svg' preserveAspectRatio='xMinYMin meet' viewBox='0 0 350 350'><style>.base { fill: white; font-family: serif; font-size: 24px; }</style><rect width='100%' height='100%' fill='";

    string svgPartTwo =

        "'/><text x='50%' y='50%' class='base' dominant-baseline='middle' text-anchor='middle'>";



    constructor() ERC721("ENSRegistry", "ENSR") {}



    function reserveName(string memory _name, string memory _bgColor) public {

        require(registeredNames[_name] == address(0), "Name Already taken");

        string memory finalSvg = string(

            abi.encodePacked(

                svgPartOne,

                _bgColor,

                svgPartTwo,

                _name,

                "</text></svg>"

            )

        );

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

        string memory finalTokenUri = string(

            abi.encodePacked("data:application/json;base64,", json)

        );

        uint256 newTokenId = _tokenIds.current();

        _safeMint(msg.sender, newTokenId);

        _setTokenURI(newTokenId, finalTokenUri);

        CName storage newCName = CNames[newTokenId];

        newCName.listed = false;

        newCName.price = 0;

        newCName.sold = 0;

        registeredNames[_name] = msg.sender;

        _tokenIds.increment();

        emit Registered(msg.sender, _name);

    }



    function sell(uint256 _tokenId, uint256 _price) public {

        require(ownerOf(_tokenId) == msg.sender, "Only NFT owner can list Item");

        require(_price > 0, "price should be greater than zero");

        CName storage editCName = CNames[_tokenId];

        editCName.listed = true;

        editCName.price = _price;

    }



    function buyNFT(uint256 _tokenId) public payable {

        require(ownerOf(_tokenId) != msg.sender, "Owner can not buy own item");

        require(CNames[_tokenId].listed == true, "nft not listed");

        require(

            CNames[_tokenId].price <= msg.value,

            "insufficient funds to purchase item"

        );

        (bool success, ) = payable(ownerOf(_tokenId)).call{value: msg.value}("");

        if (success) _transfer(ownerOf(_tokenId), msg.sender, _tokenId);

        CName storage buyCName = CNames[_tokenId];

        buyCName.owner = msg.sender;

        buyCName.listed = false;

        buyCName.sold += 1;

    }



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

        return (

            ownerOf(_tokenId),

            rCName.listed,

            rCName.price,

            rCName.sold,

            rCName.favorites

        );

    }



    function likeNft(uint256 _tokenId) public {

        require(!isFavorited(_tokenId, msg.sender), "nft already favorited");

        CName storage likeCName = CNames[_tokenId];

        likeCName.favorites.push(msg.sender);

        favorited[_tokenId].push(msg.sender);

    }



    function isFavorited(uint256 _tokenId, address _address) public view returns (bool) {

        address[] memory favorites = favorited[_tokenId];

        for(uint i = 0; i < favorites.length; i++) {

            if(favorites[i] == _address) {

                return true;

            }

        }

        return false;

    }



    function setAddressAvicon(string memory _imageUri) public {

        imageToAddress[msg.sender] = _imageUri;

    }



    function getAddressAvicon(address _address)

        public

        view

        returns (string memory)

    {

        string memory _imageUri = imageToAddress[_address];

        return _imageUri;

    }



    function _beforeTokenTransfer(

        address from,

        address to,

        uint256 tokenId

    ) internal override(ERC721, ERC721Enumerable) {

        super._beforeTokenTransfer(from, to, tokenId);

    }



    function tokenURI(uint256 tokenId)

        public

        view

        override(ERC721, ERC721URIStorage)

        returns (string memory)

    {

        return super.tokenURI(tokenId);

    }



    function supportsInterface(bytes4 interfaceId)

        public

        view

        override(ERC721, ERC721Enumerable)

        returns (bool)

    {

        return super.supportsInterface(interfaceId);

    }

}

