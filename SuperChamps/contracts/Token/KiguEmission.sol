// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import "../.././interfaces/IKiguMinter.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract KiguEmission is Ownable {
    IERC20 public kiguToken;
    IKiguMinter public minter;
    uint256 public constant WEEK = 7 * 86400;
    address[4] public wallets;
    uint256[4] public percents;

    address public emissionManager;

    uint8 public constant wallet_length = 4;

    event Distributed(uint256 indexed epoch, uint256 emission);
    event SetMinter(address indexed oldMinter, address indexed newMinter);
    event WalletsAndPercentsUpdated(address[4] indexed wallets, uint256[4] indexed percents);

    constructor(address _token) Ownable(msg.sender) {
        kiguToken = IERC20(_token);
    }

    function setMinter(address _minter) external onlyOwner{
        address oldMinter = address(minter);
        minter = IKiguMinter(_minter);
        emit SetMinter(oldMinter, _minter);
    }

    function setEmissionManager(address _emissionManager) external onlyOwner{ 
        emissionManager = _emissionManager;
    }

    modifier onlyOwnerOrEmissionManager() {
        require(msg.sender == emissionManager || msg.sender == owner(), "Not authorized");
        _;
    }

    function setWalletsAndPercents(
        address[4] calldata _wallets,
        uint256[4] calldata _percents
    ) external onlyOwner {
        require(_wallets.length == wallet_length && _percents.length == wallet_length, "lengthSize4Only");
        require(
            _percents[0] + _percents[1] + _percents[2] + _percents[3] == 10_000,
            "Invalid percentages"
        );
        
        for (uint8 i = 0; i < wallet_length; i++) {
            require(_wallets[i] != address(0), "Wallet cannot be zero address");
        }
        
        wallets = _wallets;
        percents = _percents;
        emit WalletsAndPercentsUpdated(_wallets, _percents);
    }

    function mintTokenAndDistribute() external onlyOwnerOrEmissionManager {
        require(wallets.length == wallet_length , "lengthSize4Only");

        uint256 emission = minter.mintKiguToken();

        for (uint8 i = 0; i < wallet_length; i++) {
            uint256 share = (emission * percents[i]) / 10_000;
            kiguToken.transfer(wallets[i], share);
        }

        emit Distributed(block.timestamp / WEEK, emission);
    }

    function version() external pure returns (string memory) {
        return "EmissionUpgradeable v0.0.1";
    }
}
