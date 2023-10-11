// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC721} from "../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {Base64} from "../lib/openzeppelin-contracts/contracts/utils/Base64.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
// import {ERC721URIStorage} from "../lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

error ERC721Metadata__URI_QueryFor_NonExistentToken();

contract A0FinancialGroup is ERC721, Ownable {
    uint256 private counter;
    string private s_A0Financial =
        "ipfs://bafkreifnzvbgezdniasdlwjgpg3i7kkfgts43iglm7veahio2ghc7cqlge";

    event CreatedNFT(uint256 indexed tokenId);

    constructor(
        string memory A0Financial
    ) ERC721("A0 Financial", "A0") Ownable(msg.sender) {
        A0Financial = s_A0Financial;
    }

    function mintNft() public {
        _safeMint(msg.sender, counter);
        counter++;
        emit CreatedNFT(counter);
    }

    function tokenURI(
        uint256 tokenId
    ) public view virtual override(ERC721) returns (string memory) {
        string memory imageURI = s_A0Financial;
        return
            string(
                abi.encodePacked(
                    _baseURI(),
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '{"name":"',
                                name(),
                                '", "description":"An NFT that reflects the mood of the owner, 100% on Chain!", ',
                                '", "image":"',
                                imageURI,
                                '"}'
                            )
                        )
                    )
                )
            );
    }

    // function supportsInterface(
    //     bytes4 interfaceId
    // ) public view override(ERC721, ERC721URIStorage) returns (bool) {
    //     return super.supportsInterface(interfaceId);
    // }

    function getA0Financial() public view returns (string memory) {
        return s_A0Financial;
    }
}
