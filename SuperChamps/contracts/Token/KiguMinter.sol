// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import "../.././interfaces/IKigu.sol";


contract KiguMinter {
    uint256 public constant FIXED_WEEKLY_SUPPLY = 3_000_000 * 1e18;
    uint256 public constant FIXED_MINT_END_WEEK = 30;

    IKigu public immutable kigu;
    address public immutable emissionContract;

    uint256 public totalMinted;
    uint256 public epochCount;
    uint256 public activePeriod;
    uint256 public constant WEEK = 7 * 86400;
    uint256 public constant DECAY_FACTOR = 9700;
    uint256 public lastEmission;

    event Minted(uint256 indexed week, uint256 indexed amount, uint256 indexed totalMinted);
    event EmissionContractUpdated(address indexed newEmissionContract);

    constructor(address _kiguToken, address _emissionContract) {
        require(_emissionContract != address(0), "NotEmissionContract");
        require(_kiguToken != address(0), "NotKiguTokenContract");
        kigu = IKigu(_kiguToken);
        emissionContract = _emissionContract;
        activePeriod = ((block.timestamp) / WEEK) * WEEK;
        lastEmission = FIXED_WEEKLY_SUPPLY;
    }

    modifier onlyEmissionContract() {
        require(msg.sender == emissionContract, "Not authorized");
        _;
    }

    function mintKiguToken() external onlyEmissionContract returns (uint256 emission) {
        require(block.timestamp >= activePeriod + WEEK, "Too early");

        epochCount += 1;
        activePeriod = (block.timestamp / WEEK) * WEEK;

        if (epochCount <= FIXED_MINT_END_WEEK) {
            emission = FIXED_WEEKLY_SUPPLY;
        } else {
            emission = (lastEmission * DECAY_FACTOR) / 10_000;
        }

        totalMinted = totalMinted + emission;
        kigu.mint(msg.sender, emission); // Mint to emission contract
        lastEmission = emission;

        emit Minted(epochCount, emission, totalMinted);
    }
}
