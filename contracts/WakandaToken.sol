/**
* Simple Election
* @author 
* Date created: 2022.04.05
* Github: 
* SPDX-License-Identifier: MIT
*/


pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract WakandaToken is ERC20, Ownable {
    constructor() ERC20("Wakanda ", "WKND") {}

    mapping (address => bool) public isRegistered;

    function register(address _to) external {
        uint _amount = 1 * 10 **18; // 1 ether
        isRegistered[_to] = true;
        _mint(_to, _amount);
    }
}