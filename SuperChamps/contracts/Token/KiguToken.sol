// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "../../interfaces/IKigu.sol";

contract KiguToken is ERC20, ERC20Burnable {
    address public minter;
    bool public isInitialMintDone;

    uint256 public constant INITIAL_SUPPLY = 10_000_000 * 1e18;
    uint256 public constant INITIAL_MINT_SUPPLY = 3_000_000 * 1e18;
    uint8 public constant wallet_length = 4;

    constructor() ERC20("KIGU", "KIGU") {
        minter = msg.sender;
    }

    modifier onlyMinter() {
        require(msg.sender == minter, "Not authorized");
        _;
    }

    function initialMint(address _recipient,  address[4] calldata _wallets,
        uint256[4] calldata _percents) external onlyMinter {
        require(!isInitialMintDone, "Initial mint done");
         require(_wallets.length == wallet_length && _percents.length == wallet_length, "lengthSize4Only");
        require(
            _percents[0] + _percents[1] + _percents[2] + _percents[3] == 10_000,
            "Invalid percentages"
        );

        isInitialMintDone = true;
        _mint(_recipient, INITIAL_SUPPLY);
         for (uint8 i = 0; i < wallet_length; i++) {
            uint256 share = (INITIAL_MINT_SUPPLY * _percents[i]) / 10_000;
            _mint(_wallets[i], share);
        }
    }

    function mint(address _to, uint256 _amount) external onlyMinter returns (bool) {
        _mint(_to, _amount);
        return true;
    }

    function setMinter(address _minter) external onlyMinter {
        require(_minter != address(0), "Zero address");
        minter = _minter;
    }
}
