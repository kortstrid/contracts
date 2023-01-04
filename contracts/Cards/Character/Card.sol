// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";

import "@dirtycajunrice/contracts/token/ERC721/extensions/ERC721EnumerableV2.sol";
import "@dirtycajunrice/contracts/token/ERC721/extensions/ERC721URITokenJSON.sol";
import "@dirtycajunrice/contracts/token/ERC721/extensions/ERC721BurnableV2.sol";
import "@dirtycajunrice/contracts/third-party/boba/bridge/IStandardERC721.sol";
import "@dirtycajunrice/contracts/utils/access/StandardAccessControl.sol";
import "@dirtycajunrice/contracts/utils/structs/Attributes.sol";
import "@dirtycajunrice/contracts/utils/TokenMetadata.sol";

import "./ICard.sol";


/**
* @title Kortstrid Character Card v1.0.0
* @author @DirtyCajunRice
*/
contract Card is Initializable, ICard, ERC721EnumerableV2, ERC721BurnableV2, ERC721URITokenJSON,
IStandardERC721, StandardAccessControl, PausableUpgradeable, UUPSUpgradeable {
    // libraries
    using StringsUpgradeable for uint256;
    using Attributes for Attributes.AttributeStore;

    address public bridgeContract;

    Attributes.AttributeStore private _attributes;


    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __ERC721_init("Character Card", "CCARD");
        __ERC721URITokenJSON_init("https://images.kortstrid.io/card/character/");

        __Pausable_init();
        __UUPSUpgradeable_init();
        __ERC721BurnableV2_init();
        __ERC721EnumerableV2_init();
        __StandardAccessControl_init();
    }

    function mint(address to, uint256 tokenId, bytes memory data) public onlyContract {
        (Character memory character) = abi.decode(data, (Character));
        _safeMint(to, tokenId);
        _setCharacter(character);
        _removeBurnedId(tokenId);
    }

    function getCard(uint256 tokenId) public view returns (Character memory) {
        Rarity rarity = Rarity(_attributes.getValue(tokenId, 1, 1));
        (uint256 elemCount, uint256 dmgCount, uint256 weakCount, uint256 defCount) = _getModCounts(rarity);


        return Character({
            tokenId: tokenId,
            generation: _attributes.getValue(tokenId, 1, 0),
            rarity: rarity,
            visual: Visual({
                character: _attributes.getValue(tokenId, 2, 0),
                region: Region({
                    id: _attributes.getValue(tokenId, 2, 1),
                    variant: _attributes.getValue(tokenId, 2, 2)
                })
            }),
            battle: Battle({
                strengths: Strengths({
                    top: _attributes.getValue(tokenId, 3, 0),
                    right: _attributes.getValue(tokenId, 3, 1),
                    bottom: _attributes.getValue(tokenId, 3, 2),
                    left: _attributes.getValue(tokenId, 3, 3)
                }),
                modifiers: Modifiers({
                    damage: _getCardMods(tokenId, dmgCount, 8),
                    weakness: _getCardMods(tokenId, weakCount, 12),
                    defense: _getCardMods(tokenId, defCount, 16)
                }),
                elements: _getCardMods(tokenId, elemCount, 4)
            })
        });
    }

    function _getCardMods(uint256 tokenId, uint256 count, uint256 start) internal view returns (uint256[] memory) {
        uint256[] memory mods = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            mods[i] = _attributes.getValue(tokenId, 3, start + i);
        }
        return mods;
    }

    function bridgeExtraData(uint256 tokenId) external view returns(bytes memory) {
        return abi.encode(getCard(tokenId));
    }

    function tokenURIJSON(uint256 tokenId) public view override(ERC721URITokenJSON) returns(string memory) {
        Character memory card = getCard(tokenId);


        TokenMetadata.Attribute[] memory attributes = new TokenMetadata.Attribute[](7);

        return makeMetadataJSON(
            card.tokenId,
            _attributes.getSkillName(2, card.visual.character),
            'Kortstrid Character Card',
            attributes
        );
    }

    ///
    /// Internal
    ///

    function _getModCounts(Rarity rarity) internal pure returns (uint256 elem, uint256 dmg, uint256 weak, uint256 def) {
        elem = rarity == Rarity.Common ? 0 : rarity == Rarity.Supreme ? 2 : 1;
        dmg = rarity == Rarity.Legendary ? 2 : 1;
        weak = uint8(rarity) < 3 ? 3 - uint8(rarity) : 0;
        def = rarity == Rarity.Supreme ? 1 : uint8(rarity) < 2 ? 0 : uint8(rarity) < 4 ? 1 : 2;
    }

    function _setCharacter(Character memory character) internal {
        // base
        _attributes.setValue(character.tokenId, 1, 0, character.generation);
        _attributes.setValue(character.tokenId, 1, 1, uint256(character.rarity));
        // visual
        _attributes.setValue(character.tokenId, 2, 0, character.visual.character);
        _attributes.setValue(character.tokenId, 2, 1, character.visual.region.id);
        _attributes.setValue(character.tokenId, 2, 2, character.visual.region.variant);
        // battle
        _attributes.setValue(character.tokenId, 3, 0, character.battle.strengths.top);
        _attributes.setValue(character.tokenId, 3, 1, character.battle.strengths.right);
        _attributes.setValue(character.tokenId, 3, 2, character.battle.strengths.bottom);
        _attributes.setValue(character.tokenId, 3, 3, character.battle.strengths.left);
        for (uint256 i = 0; i < character.battle.elements.length; i++) {
            _attributes.setValue(character.tokenId, 3, 4 + i, character.battle.elements[i]);
        }
        for (uint256 i = 0; i < character.battle.modifiers.damage.length; i++) {
            _attributes.setValue(character.tokenId, 3, 8 + i, character.battle.modifiers.damage[i]);
        }
        for (uint256 i = 0; i < character.battle.modifiers.weakness.length; i++) {
            _attributes.setValue(character.tokenId, 3, 12 + i, character.battle.modifiers.weakness[i]);
        }
        for (uint256 i = 0; i < character.battle.modifiers.defense.length; i++) {
            _attributes.setValue(character.tokenId, 3, 16 + i, character.battle.modifiers.defense[i]);
        }
    }

    ///
    /// Admin
    ///

    function setImageBaseUri(string memory _imageBaseURI) external onlyAdmin {
        imageBaseURI = _imageBaseURI;
    }

    function setBridgeContract(address _bridgeContract) public onlyAdmin {
        bridgeContract = _bridgeContract;
    }

    function pause() public onlyAdmin {
        _pause();
    }

    function unpause() public onlyAdmin {
        _unpause();
    }

    ///
    /// Overrides
    ///

    function tokenURI(uint256 tokenId)
    public
    view
    virtual
    override(ERC721URITokenJSON, ERC721Upgradeable)
    returns(string memory) {
        return ERC721URITokenJSON.tokenURI(tokenId);
    }

    function burn(uint256 tokenId) public virtual override(IStandardERC721, ERC721BurnableV2) {
        super.burn(tokenId);
    }

    function _authorizeUpgrade(address newImplementation) internal onlyAdmin override {}

    function supportsInterface(bytes4 interfaceId) public view virtual override(
        AccessControlEnumerableUpgradeable,
        ERC721EnumerableV2,
        ERC721Upgradeable,
        IERC165Upgradeable
    ) returns (bool)
    {
        return type(ICard).interfaceId == interfaceId || super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal virtual override(ERC721EnumerableV2, ERC721Upgradeable) {
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
    }
}