// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract ManualToken {
    mapping(address => uint256) private s_balances;

    event Transfer(address indexed from, address indexed to, uint256 value);

    function name() public pure returns (string memory) {
        return "Manual Token";
    }
    // string public name = "Manual Token";

    function symbol() public pure returns (string memory) {
        return "MT";
    }

    function totalSupply() public pure returns (uint256) {
        return 100 ether;
    }

    function decimals() public pure returns (uint8) {
        return 18;
    }

    function balanceOf(address _owner) public view returns (uint256) {
        return s_balances[_owner];
    }

    function transfer(address _to, uint256 _value) public returns (bool success) {
        require(_to != address(0), "Invalid address");
        require(s_balances[msg.sender] >= _value, "Insufficient balance");
        s_balances[msg.sender] = balanceOf(msg.sender) - _value;
        s_balances[_to] += _value;
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(_from != address(0), "Invalid address");
        require(_to != address(0), "Invalid address");
        require(s_balances[_from] >= _value, "Insufficient balance");
        s_balances[_from] -= _value;
        s_balances[_to] += _value;
        emit Transfer(_from, _to, _value);
        return true;
    }
}
