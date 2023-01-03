// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

import "@dirtycajunrice/contracts/third-party/boba/turing/TuringClient.sol";
import "@dirtycajunrice/contracts/utils/access/StandardAccessControl.sol";
import "@dirtycajunrice/contracts/utils/math/Numbers.sol";

import "../Cards/Character/ICharacterCard.sol";
import "../utils/Allowlist.sol";

/**
* @title Kortstrid Character Card Minter v1.0.0
* @author @DirtyCajunRice
*/
contract CharacterCardMinter is Initializable, ICharacterCard, PausableUpgradeable, StandardAccessControl,
ReentrancyGuardUpgradeable, Allowlist, BobaL2TuringClient, UUPSUpgradeable {
    // libraries
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    using Numbers for uint256;
    // constants

    // enums/structs


    // public vars
    uint256 public startTime;
    uint256 public price;

    address public treasury;

    uint256[] private _classes;
    uint256[] private _regions;

    CountersUpgradeable.Counter private _counter;

    modifier gated() {
        require(block.timestamp >= startTime || _hasAdminRole(msg.sender), "Mint has not started");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __Pausable_init();
        __UUPSUpgradeable_init();
        __StandardAccessControl_init();
        __BobaL2TuringClient_init(
            0x4200000000000000000000000000000000000020, // TuringCredit
            0x680e176b2bbdB2336063d0C82961BDB7a52CF13c // TuringHelper
        );

        startTime = 1661641200;

        __Allowlist_init(startTime + 2 days);

        treasury = 0xD2578A0b2631E591890f28499E9E8d73F21e5895;
        price = 250_000_000; // USDC is 6 decimals

        _counter.increment();
    }

    function mintCard() external payable onlyAllowlisted nonReentrant whenNotPaused {
        _payTuringFee();
        uint256 tokenId = _counter.current();
        _counter.increment();

        uint256 rand = _getTuringHelper().Random();
        uint256[] memory chunks = rand.chunkUintX(10_000, 15);

        Rarity rarity = rollRarity(chunks[0]);
        Character memory card = Character({
            tokenId: tokenId,
            generation: 0,
            rarity: rarity,
            visual: Visual({
                class: rollClass(chunks[1]),
                region: rollRegion(chunks)
            }),
            battle: Battle({
                strengths: rollStrengths(rarity, chunks),
                modifiers: rollModifiers(rarity, chunks),
                elements: rollElement(rarity, chunks[12])
            })
        });

    }
    function rollRarity(uint256 rand) internal pure returns (Rarity) {
        return rand % 100 >= 90 ? Rarity.Uncommon : Rarity.Common;
    }

    function rollClass(uint256 rand) internal view returns (uint256) {
        uint256[] memory classes = _classes;
        return classes[rand % _classes.length];
    }

    function rollRegion(uint256[] memory rand) internal view returns (Region memory) {
        uint256[] memory regions = _regions;
        return Region({
            id: regions[rand[2] % regions.length],
            variant: (rand[3] % 3) + 1
        });
    }

    //
    // Internal
    //

    function rollStrengths(Rarity rarity, uint256[] memory rand) internal pure returns (Strengths memory) {
        // NOTE: Only accounts for common / uncommon as we should not be fresh minting Rare+;
        uint256 min = rarity == Rarity.Common ? 1 : 15;
        uint256 max = rarity == Rarity.Common ? 20 : 30;
        return Strengths({
            top: (rand[4] % (max-min)) + min,
            right: (rand[5] % (max-min)) + min,
            bottom: (rand[6] % (max-min)) + min,
            left: (rand[7] % (max-min)) + min
        });
    }

    function rollModifiers(Rarity rarity, uint256[] memory rand) internal pure returns (Modifiers memory) {
        return Modifiers({
            damage: rollModifier(rand, 8, 1),
            // NOTE: Only accounts for common / uncommon as we should not be fresh minting Rare+;
            weakness: rollModifier(rand, 9, rarity == Rarity.Common ? 3 : 2),
            defense: new uint256[](0)
        });
    }

    function rollModifier(uint256[] memory rand, uint256 first, uint256 count) internal pure returns (uint256[] memory) {
        uint256[] memory results = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            results[i] = rand[first+i] % 8;
        }
        return results;
    }

    function rollElement(Rarity rarity, uint256 rand) internal pure returns (uint256[] memory) {
        if (rarity == Rarity.Common) {
            return new uint256[](0);
        }
        uint256[] memory elements = new uint256[](1);
        elements[0] = rand % 12;
        return elements ;
    }

    function _authorizeUpgrade(address newImplementation) internal virtual override onlyAdmin {}

    //
    // Admin
    //
    function pause() public onlyAdmin {
        _pause();
    }

    function unpause() public onlyAdmin {
        _unpause();
    }

    function setStartTime(uint256 time) external onlyAdmin {
        startTime = time;
    }

    function setTreasury(address _treasury) external onlyAdmin {
        treasury = _treasury;
    }

    function setPrice(uint256 _price) external onlyAdmin {
        price = _price;
    }

    function setClasses(uint256[] memory classes) external onlyAdmin {
        _classes = classes;
    }

    function setRegions(uint256[] memory regions) external onlyAdmin {
        _regions = regions;
    }
}