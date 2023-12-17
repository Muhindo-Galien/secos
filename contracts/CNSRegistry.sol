//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

// We first import some OpenZeppelin Contracts.
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "hardhat/console.sol"; // to allow console logging for easier debuging

// We inherit the contracts we imported. This means we'll have access
// to the inherited contract's methods. So 'is' keyword gives it power
// to inherit other contracts
contract CNSRegistry is ERC721, ERC721Enumerable, ERC721URIStorage {
    // this allows us to help us keep track of tokenIds.
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    struct CName {
        address owner;
        bool listed;
        uint256 price;
        uint256 sold;
        address[] favorites;
    }
    mapping(uint256 => CName) public CNames; //to keep track of the structs
    mapping(string => address) public registeredNames; //to  map the registered names to the owners
    mapping(uint256 => address) public favorited; // to keep track of those that have already liked an nft
    mapping(address => string) public imageToAddress; // to map the address/users to the avicons
    event Registered(address indexed who, string name); // emit this upon successfull registration

    // This is our SVG code. All we need to change is the name that's displayed. Everything else stays the same.
    // So, we make a baseSvg variable here that all our NFTs can use.
    // We split the SVG at the part where it asks for the background color.
    string svgPartOne =
        "<svg xmlns='http://www.w3.org/2000/svg' preserveAspectRatio='xMinYMin meet' viewBox='0 0 350 350'><style>.base { fill: white; font-family: serif; font-size: 24px; }</style><rect width='100%' height='100%' fill='";
    string svgPartTwo =
        "'/><text x='50%' y='50%' class='base' dominant-baseline='middle' text-anchor='middle'>";

    // initialising the name and it's symbol of the ERC721 contract.
    constructor() ERC721("ENSRegistry", "ENSR") {}

    // A function used to reserve the CNS names
    function reserveName(string memory _name, string memory _bgColor) public {
        // query to see if the name is still available
        require(registeredNames[_name] == address(0), "Name Already taken");
        // if yes, we reconstruct the svg to  include the name and bg color
        string memory finalSvg = string(
            abi.encodePacked(
                svgPartOne,
                _bgColor,
                svgPartTwo,
                _name,
                "</text></svg>"
            )
        );
        //@dev to autofill the .celo extention to the input name
        string memory name = string(abi.encodePacked(_name, ".celo"));
        // console.log(name)
        // Get all the JSON metadata in place and base64 encode it.
        string memory json = Base64.encode( // this whole block encodes our json data into base64
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "', // here we dynmaically add the name to it
                        // We set the title of our NFT as the generated word.
                        name,
                        '", "description": "Your Unique identity on the celo Blockchain.", "image": "data:image/svg+xml;base64,',
                        // We add data:image/svg+xml;base64 and then append our base64 encode our svg.
                        Base64.encode(bytes(finalSvg)),
                        '"}'
                    )
                )
            )
        );

        // Just like before, we prepend data:application/json;base64, to our data.
        string memory finalTokenUri = string(
            abi.encodePacked("data:application/json;base64,", json) // so here we put it all together
        );
        /** 
        console.log(
            string(
                abi.encodePacked( // passed it in as a parameter
                    "https://nftpreview.0xdev.codes/?code=", // with this we can do a quick preview of the image and the contents of the json without deploying it again and again on the opensea testnet
                    finalTokenUri
                )
            )
        );
        */
        // Actually mint the NFT to the sender using msg.sender.
        uint256 newTokenId = _tokenIds.current();
        _safeMint(msg.sender, newTokenId);

        //  Updated our URI to be consistent with our Json files
        _setTokenURI(newTokenId, finalTokenUri);
        // updated the struct
        CName storage newCName = CNames[newTokenId];
        newCName.owner = msg.sender;
        newCName.listed = false;
        newCName.price = 0;
        newCName.sold = 0;
        registeredNames[_name] = msg.sender;
        // Increment the counter for when the next NFT is minted.
        _tokenIds.increment();
        // emit the event
        emit Registered(msg.sender, _name);
    }

    // function to list the nfts
    function sell(uint256 _tokenId, uint256 _price) public {
        require(
            CNames[_tokenId].owner == msg.sender,
            "Only NFT owner can list Item"
        );
        require(_price > 0, "price should be greater than zero");
        // update the struct
        CName storage editCName = CNames[_tokenId];
        editCName.listed = true;
        editCName.price = _price;
    }

    // function to buy an nft and transfer ownership
    function buyNFT(uint256 _tokenId) public payable {
        require(
            CNames[_tokenId].owner != msg.sender,
            "Owner can not buy own item"
        );
        require(CNames[_tokenId].listed == true, "nft not listed");
        require(
            CNames[_tokenId].price <= msg.value,
            "insufficient funds to purchase item"
        );

        (bool success, ) = payable(CNames[_tokenId].owner).call{
            value: msg.value
        }(""); // pay for the nft
        if (success) _transfer(CNames[_tokenId].owner, msg.sender, _tokenId); // transfer nft
        // update the struct
        CName storage buyCName = CNames[_tokenId];
        buyCName.owner = msg.sender;
        buyCName.listed = false;
        buyCName.sold += 1;
    }

    // function to fetch the nfts
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
            rCName.owner,
            rCName.listed,
            rCName.price,
            rCName.sold,
            rCName.favorites
        );
    }

    // function to like the nfts
    function likeNft(uint256 _tokenId) public {
        require(favorited[_tokenId] != msg.sender, "nft already favorited");
        CName storage likeCName = CNames[_tokenId];
        likeCName.favorites.push(msg.sender);
        favorited[_tokenId] = msg.sender;
    }

    // function to update the struct with the image of the users
    function setAddressAvicon(string memory _imageUri) public {
        imageToAddress[msg.sender] = _imageUri;
    }

    // function to query the mapping for the users' imageUri/avicon
    function getAddressAvicon(address _address)
        public
        view
        returns (string memory)
    {
        string memory _imageUri = imageToAddress[_address];
        return _imageUri;
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
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
