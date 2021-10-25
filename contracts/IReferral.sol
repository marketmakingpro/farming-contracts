// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IReferral {
    function recordReferral(address user, address referrer) external;
    function getReferrer(address user) external view returns (address);
}