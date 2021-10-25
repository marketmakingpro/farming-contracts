// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./lib/ERC20.sol";

contract MMPROtoken is ERC20('MMPRO', 'MMPRO') {

    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }
    
}