// SPDX-License-Identifier: GPL-3.0
        
pragma solidity >=0.4.22 <0.9.0;

// This import is automatically injected by Remix
import "remix_tests.sol"; 

// This import is required to use custom transaction context
// Although it may fail compilation in 'Solidity Compiler' plugin
// But it will work fine in 'Solidity Unit Testing' plugin
import "remix_accounts.sol";
import "../contracts/SCMetagameHouseRewards.sol";
import "../contracts/SCMetagameHouses.sol";
import "../contracts/SuperChampsToken.sol";
import "../contracts/SCPermissionsManager.sol";
import "../contracts/SCMetagameRegistry.sol";
import "../contracts/ExponentialVestingEscrow.sol";
import "./VestingEscrowFactoryStub.sol";
// File name has to end with '_test.sol', this file can contain more than one testSuite contracts
contract testSuite {
    SuperChampsToken _token;
    SCPermissionsManager _permissions;
    SCMetagameRegistry _metadata;
    SCMetagameHouses _houses;

    /// 'beforeAll' runs before all other tests
    /// More special functions are: 'beforeEach', 'beforeAll', 'afterEach' & 'afterAll'
    function beforeAll() public {
        // <instantiate contract>
        _permissions = new SCPermissionsManager();

        _token = new SuperChampsToken(
            _permissions, 
            new VestingEscrowFactoryStub(),
            address(this),
            address(this)
        );

        _permissions.addRole(ISCPermissionsManager.Role.GLOBAL_ADMIN, address(_token));
        _token.TGE(address(this), 0);
        _token.initializeEmmissions(0);

        _metadata = new SCMetagameRegistry(
            address(_permissions)
        );

        _houses = new SCMetagameHouses(
            address(_permissions),
            address(_token),
            address(_metadata),
            address(_token.metagameTreasury())
        );

        _permissions.addRole(ISCPermissionsManager.Role.TRANSFER_ADMIN, address(_houses));
        _token.approve(address(_houses), type(uint256).max);
    }

    function addHouses() public {
        _houses.addHouse("HOUSE1");
        _houses.addHouse("HOUSE2");
        _houses.addHouse("HOUSE3");

        _permissions.addRole(ISCPermissionsManager.Role.TRANSFER_ADMIN, _houses.getHouseRewardsStaker("HOUSE1"));
        _permissions.addRole(ISCPermissionsManager.Role.TRANSFER_ADMIN, _houses.getHouseRewardsStaker("HOUSE2"));
        _permissions.addRole(ISCPermissionsManager.Role.TRANSFER_ADMIN, _houses.getHouseRewardsStaker("HOUSE3"));

        Assert.ok(_houses.houseCount() == 3, "Not 3 Houses");

        _metadata.registerUserInfo(
            "USER_1", 
            address(this), 
            "house_id", 
            "HOUSE3", 
            0, 0, bytes(""));

        bytes32 _hash1 = keccak256(bytes(_metadata.metadataFromAddress(address(this), "house_id")));
        bytes32 _hash2 = keccak256("HOUSE3");

        Assert.ok(_hash1 == _hash2, "House not assigned");
    }

    function assignAwardTiers() public {
        uint256[] memory _tiers = new uint256[](3);
        _tiers[0] = 500;
        _tiers[1] = 300;
        _tiers[2] = 200;

        _houses.assignAwardTiers(_tiers);

        Assert.ok(  _houses.award_tiers_bps(0) == 500 &&
                    _houses.award_tiers_bps(1) == 300 &&
                    _houses.award_tiers_bps(2) == 200, "Not Set");
    }

    function distributeRewards() public payable {
        Assert.ok(_token.allowance(address(this), address(_houses)) == type(uint256).max, "Allowance not set");

        ExponentialVestingEscrow _emissions = ExponentialVestingEscrow(_token.metagameEmissions());
        _emissions.TEST_spoofTimeStamp(6 days);
        _emissions.claim(
            _token.metagameTreasury(),
            0
        );

        Assert.ok(_token.balanceOf(_token.metagameTreasury()) > 0, "Emissions not claimed");
        Assert.ok(_houses.treasury() == _token.metagameTreasury(), "Wrong treasury address");
        Assert.ok(_houses.treasury() == address(this), "Wrong treasury address 2");
        
        _houses.distributeRewards();
    }

    function stakeTokens() public {
        ExponentialVestingEscrow _emissions = ExponentialVestingEscrow(_token.metagameEmissions());
        _emissions.TEST_spoofTimeStamp(30 days);
        _emissions.claim(
            _token.metagameTreasury(),
            0
        );

        Assert.ok(_token.balanceOf(address(this)) > 1 ether, "No Stakeable CHAMP!");
        SCMetagameHouseRewards _staker = SCMetagameHouseRewards(_houses.getHouseRewardsStaker("HOUSE3"));

        Assert.ok(address(_staker) != address(0), "Missing Staker!");
        Assert.ok(_permissions.hasRole(ISCPermissionsManager.Role.TRANSFER_ADMIN, address(_staker)), "Missing role!");

        _token.approve(address(_staker), type(uint256).max);

        _staker.TEST_spoofTimeStamp(1 minutes);
        _staker.stake(1 ether);
        _staker.TEST_spoofTimeStamp(1 days);

        uint256 _earned = _staker.earned(address(this));
        Assert.ok(_earned > 0, "No Earnings!");
    }

    function reportHouseScores() public {
        uint256[] memory _scores = new uint256[](3);
        _scores[0] = 500;
        _scores[1] = 300;
        _scores[2] = 200;

        string[] memory _orderedHouses = new string[](3);
        _orderedHouses[0] = "HOUSE2";
        _orderedHouses[1] = "HOUSE3";
        _orderedHouses[2] = "HOUSE1";

        _houses.reportHouseScores(_houses.current_epoch(), _scores, _orderedHouses);

        (uint256 _score, uint256 _order) = _houses.getHouseScoreAndOrder(_houses.current_epoch(), "HOUSE1");
        Assert.ok(_score == 200 && _order == 3, "Not set accurately");
    }
}
    