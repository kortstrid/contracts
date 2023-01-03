// SPDX-License-Identifier: GPL-V3
pragma solidity ^0.8.17;

interface ICharacterCard {
    enum Rarity { Common, Uncommon, Rare, Legendary, Epic, Supreme }

    struct Region {
        uint256 id;
        uint256 variant;
    }

    struct Strengths {
        uint256 top;
        uint256 right;
        uint256 bottom;
        uint256 left;
    }

    struct Modifiers {
        uint256[] damage;
        uint256[] weakness;
        uint256[] defense;
    }

    struct Visual {
        uint256 class;
        Region region;
    }

    struct Battle {
        Strengths strengths;
        Modifiers modifiers;
        uint256[] elements;
    }

    struct Character {
        uint256 tokenId;
        uint256 generation;
        Rarity rarity;
        Visual visual;
        Battle battle;
    }
}