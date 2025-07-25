// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../.././interfaces/IKigu.sol";

contract KiguMinterUpgradeable is OwnableUpgradeable {
    uint256 public constant INITIAL_SUPPLY = 10_000_000 * 1e18;
    uint256 public constant FIXED_WEEKLY_SUPPLY = 3_000_000 * 1e18;
    uint256 public constant MAX_TOTAL_SUPPLY = 200_000_000 * 1e18;
    uint256 public constant FIXED_MINT_END_WEEK = 30;

    uint256[4] public distributionPercents;
    address[4] public distributionWallets;

    uint256 public totalMinted;
    uint256 public epochCount;
    uint256 public activePeriod;
    uint256 public WEEK;
    uint256 public decayPerWeek;
    uint256 public lastEmission;

    IKigu public _kigu;

    address public minter;

    event Minted(uint256 indexed week, uint256 amount, uint256 totalMinted);
    event MinterUpdated(address indexed newMinter);

    constructor() {}

    function initialize(address kiguToken) public initializer {
        __Ownable_init(_msgSender());
        _kigu = IKigu(kiguToken);
        WEEK = 1 weeks;
        activePeriod = ((block.timestamp + WEEK) / WEEK) * WEEK;
        distributionPercents = [6667, 1333, 1333, 667];
        lastEmission = FIXED_WEEKLY_SUPPLY;
    }

    modifier onlyOwnerOrMinter() {
        require(msg.sender == owner() || msg.sender == minter, "Not authorized");
        _;
    }

    function setMinter(address _minter) external onlyOwner {
        require(_minter != address(0), "Invalid minter");
        minter = _minter;
        emit MinterUpdated(_minter);
    }

    function setMintingConfig(
        address[4] memory wallets,
        uint256[4] memory percents,
        uint256 decay
    ) external onlyOwner {
        require(
            percents[0] + percents[1] + percents[2] + percents[3] == 10_000,
            "Invalid distribution percentages"
        );
        require(decay > 0, "Decay should be > 0");

        distributionWallets = wallets;
        distributionPercents = percents;
        decayPerWeek = decay;
    }

    function updatePeriod() external onlyOwnerOrMinter {
        require(block.timestamp >= activePeriod + WEEK, "Too early");
        require(totalMinted < MAX_TOTAL_SUPPLY, "Minting complete");

        epochCount += 1;
        activePeriod = (block.timestamp / WEEK) * WEEK;

        uint256 emission;
        if (epochCount <= FIXED_MINT_END_WEEK) {
            emission = FIXED_WEEKLY_SUPPLY;
        } else {
            uint256 decayFactor = 100 - decayPerWeek;
            emission = (lastEmission * decayFactor) / 100;
        }

        if (totalMinted + emission > MAX_TOTAL_SUPPLY) {
            emission = MAX_TOTAL_SUPPLY - totalMinted;
        }

        uint minterBalance = _kigu.balanceOf(address(this));
        emission -= minterBalance;
        totalMinted += emission;
        _kigu.mint(address(this), emission);

        lastEmission = emission;

        for (uint256 i = 0; i < 4; i++) {
            uint256 share = (emission * distributionPercents[i]) / 10_000;
            require(
                _kigu.transfer(distributionWallets[i], share),
                "Transfer failed"
            );
        }

        emit Minted(epochCount, emission, totalMinted);
    }

    function version() external pure returns (string memory) {
        return "MinterUpgradeable v2.0.0";
    }
}
