// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.24;

import "../.././interfaces/IKigu.sol";


contract KiguMinter {
    uint256 public constant INITIAL_SUPPLY = 10_000_000 * 1e18;
    uint256 public constant FIXED_WEEKLY_SUPPLY = 3_000_000 * 1e18;
    uint256 public constant FIXED_MINT_END_WEEK = 30;

    IKigu public immutable _kigu;
    address public emissionContract;

    uint256 public totalMinted;
    uint256 public epochCount;
    uint256 public activePeriod;
    uint256 public WEEK;
    uint256 public constant decayPerWeek = 300;
    uint256 public lastEmission;

    event Minted(uint256 indexed week, uint256 amount, uint256 totalMinted);
    event EmissionContractUpdated(address indexed newEmissionContract);

    constructor(address kiguToken, address _emissionContract) {
        require(_emissionContract != address(0), "NotEmissionContract");
        require(kiguToken != address(0), "NotKiguTokenContract");
        _kigu = IKigu(kiguToken);
        emissionContract = _emissionContract;
        WEEK = 30 seconds;
        activePeriod = ((block.timestamp + WEEK) / WEEK) * WEEK;
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
            uint256 decayFactor = 10_000 - decayPerWeek;
            emission = (lastEmission * decayFactor) / 10_000;
        }

        totalMinted = totalMinted + emission;
        _kigu.mint(msg.sender, emission); // Mint to emission contract
        lastEmission = emission;

        emit Minted(epochCount, emission, totalMinted);
    }
}
