// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.24;

import "../.././interfaces/IKigu.sol";

contract KiguToken is IKigu, IERC20Burnable {
    string public constant name = "KIGU";
    string public constant symbol = "KIGU";
    uint8 public constant decimals = 18;
    uint public totalSupply;

    address public minter;

    mapping(address => uint) public balanceOf;
    mapping(address => mapping(address => uint)) public allowance;

    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);

    uint256 public constant INITIAL_SUPPLY = 10_000_000 * 1e18;

    bool public isInitialMintDone;

    constructor() {
        minter = msg.sender;
        _mint(msg.sender, 0);
    }

    //assumption this should not be called on epoch filp
    function initialMint(address _recipient) external {
        require(msg.sender == minter && !isInitialMintDone);
        isInitialMintDone = true;
        _mint(_recipient, INITIAL_SUPPLY);
    }


    function _mint(address _to, uint _amount) internal returns (bool) {
        totalSupply += _amount;
        unchecked {
            balanceOf[_to] += _amount;
        }
        emit Transfer(address(0), _to, _amount);
        return true;
    }

    function mint(address _to, uint _amount) external override returns (bool) {
        require(msg.sender == minter, "Only minter can mint");
        return _mint(_to, _amount);
    }

    function approve(address _spender, uint _value) external override returns (bool) {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function transfer(address _to, uint _value) external override returns (bool) {
        return _transfer(msg.sender, _to, _value);
    }

    function transferFrom(address _from, address _to, uint _value) external override returns (bool) {
        uint allowed = allowance[_from][msg.sender];
        if (allowed != type(uint).max) {
            allowance[_from][msg.sender] -= _value;
        }
        return _transfer(_from, _to, _value);
    }

    function _transfer(address _from, address _to, uint _value) internal returns (bool) {
        balanceOf[_from] -= _value;
        unchecked {
            balanceOf[_to] += _value;
        }
        emit Transfer(_from, _to, _value);
        return true;
    }

    function setMinter(address _minter) external {
        require(msg.sender == minter);
        minter = _minter;
    }

    function burn(uint256 value) external returns (bool) {
        _burn(msg.sender, value);
        return true;
    }

    function burnFrom(address _from, uint _value) external returns (bool) {
        uint allowed_from = allowance[_from][msg.sender];
        if (allowed_from != type(uint).max) {
            allowance[_from][msg.sender] -= _value;
        }
        _burn(_from, _value);
        return true;
    }

    function _burn(address _from, uint _amount) internal returns (bool) {
        totalSupply -= _amount;
        balanceOf[_from] -= _amount;
        emit Transfer(_from, address(0x0), _amount);
        return true;
    }
}
