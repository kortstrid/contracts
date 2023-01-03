// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;


import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

abstract contract Allowlist is Initializable {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    EnumerableSetUpgradeable.AddressSet private _allowlist;
    uint256 private _endTime;

    modifier onlyAllowlisted() {
        require(block.timestamp >= _endTime || _allowlist.contains(msg.sender));
        _;
    }
    function __Allowlist_init(uint256 endTime) internal onlyInitializing {
        _endTime = endTime;
    }

    function getAllowlist() public view virtual returns (address[] memory) {
        return _allowlist.values();
    }

    function getAllowlistCount() public view virtual returns (uint256) {
        return _allowlist.length();
    }

    function allowlistEndTime() public view virtual returns (uint256) {
        return _endTime;
    }

    function allowlistActive() public view virtual returns (bool) {
        return block.timestamp <= _endTime;
    }

    function isAllowlisted(address account) public view virtual returns (bool) {
        return _allowlist.contains(account);
    }

    function _addAllowlisted(address account) internal virtual {
        _allowlist.add(account);
    }

    function _revokeAllowlisted(address account) internal virtual {
        _allowlist.remove(account);
    }

    uint256[49] private __gap;
}