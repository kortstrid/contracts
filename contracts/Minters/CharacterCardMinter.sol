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
        uint256 roll = rand[3] % 100;
        return Region({
            id: regions[rand[2] % regions.length],
            variant: roll < 6 ? 1 : roll < 18 ? 2 : 3
        });
    }

    //
    // Internal
    //

    function rollStrengths(uint256[] memory rand) internal pure returns (Strengths memory) {
        // NOTE: Only accounts for common / uncommon as we should not be fresh minting Rare+;

        return Strengths({
            top: rollStrength(rand[4]),
            right: rollStrength(rand[5]),
            bottom: rollStrength(rand[6]),
            left: rollStrength(rand[7])
        });
    }

    function rollStrength(uint256 rand) internal pure returns (uint256) {
        uint256 roll = rand % 1000;
        uint256 min = 1;
        if (roll < 125) {
            return 1;
        }
        roll -= 125;
        min += 1;
        if (roll < 400) {
            return (roll % 4) + min;
        }
        min += 4;
        roll -= 400;
        if (roll < 250) {
            return (roll % 5) + min;
        }
        min += 5;
        roll -= 250;
        if (roll < 125) {
            return (roll % 5) + min;
        }
        min += 5;
        roll -= 125;
        return (roll % 5) + min;
    }

    function rollModifiers(uint256[] memory rand) internal pure returns (Modifiers memory) {
        return Modifiers({
            damage: rollModifier(true, rand, 8, 1),
            // NOTE: Only accounts for common / uncommon as we should not be fresh minting Rare+;
            weakness: rollModifier(false, rand, 9, 3),
            defense: new uint256[](0)
        });
    }

    function rollModifier(
        bool damage,
        uint256[] memory rand,
        uint256 first,
        uint256 count
    ) internal pure returns (uint256[] memory) {
        uint256[] memory results = new uint256[](count);
        if (damage) {
            uint256 r = rand[0] % 100;
            results[0] = r < 10 ? 0 : r < 20 ? 1 : r < 53 ? 2 : r < 58 ? 3 : r < 84 ? 4 : r < 90 ? 5 : r < 95 ? 6 : 7;
        } else {
            for (uint256 i = 0; i < count; i++) {
                results[i] = rand[first+i] % 8;
            }
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
}