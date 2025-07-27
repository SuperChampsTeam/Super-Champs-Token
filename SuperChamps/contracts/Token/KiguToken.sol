// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "../../interfaces/IKigu.sol";

contract KiguToken is ERC20, ERC20Burnable, IKigu {
    address public minter;
    bool public isInitialMintDone;

    uint256 public constant INITIAL_SUPPLY = 10_000_000 * 1e18;

    constructor() ERC20("KIGU", "KIGU") {
        minter = msg.sender;
    }

    modifier onlyMinter() {
        require(msg.sender == minter, "Not authorized");
        _;
    }

    function initialMint(address _recipient) external onlyMinter {
        require(!isInitialMintDone, "Initial mint done");
        isInitialMintDone = true;
        _mint(_recipient, INITIAL_SUPPLY);
    }

    function mint(address _to, uint256 _amount) external onlyMinter override returns (bool) {
        _mint(_to, _amount);
        return true;
    }

    function setMinter(address _minter) external onlyMinter {
        require(_minter != address(0), "Zero address");
        minter = _minter;
    }
}
