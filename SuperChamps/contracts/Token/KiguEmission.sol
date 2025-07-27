// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../.././interfaces/IKiguMinter.sol";
import "../.././interfaces/IKigu.sol";


contract KiguEmission is OwnableUpgradeable {
    IKigu public token;
    IKiguMinter public minter;

    address[4] public wallets;
    uint256[4] public percents;

    address public emissionManager;

    event Distributed(uint256 indexed epoch, uint256 emission);

    function initialize(address _token) public initializer {
        __Ownable_init(_msgSender());
        token = IKigu(_token);
    }

    function setMinter(address _minter) external onlyOwner{
        minter = IKiguMinter(_minter);
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
        require(
            _percents[0] + _percents[1] + _percents[2] + _percents[3] == 10_000,
            "Invalid percentages"
        );
        wallets = _wallets;
        percents = _percents;
    }

    function mintTokenAndDistribute() external onlyOwnerOrEmissionManager {
        uint256 emission = minter.mintKiguToken();

        for (uint256 i = 0; i < 4; i++) {
            uint256 share = (emission * percents[i]) / 10_000;
            require(token.transfer(wallets[i], share), "Transfer failed");
        }

        emit Distributed(block.timestamp / 1 weeks, emission);
    }

    function version() external pure returns (string memory) {
        return "EmissionUpgradeable v0.0.1";
    }
}
