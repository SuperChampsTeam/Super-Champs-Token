// SPDX-License-Identifier: GPL-3.0
        
pragma solidity >=0.4.22 <0.9.0;

// This import is automatically injected by Remix
import "remix_tests.sol"; 

// This import is required to use custom transaction context
// Although it may fail compilation in 'Solidity Compiler' plugin
// But it will work fine in 'Solidity Unit Testing' plugin
import "remix_accounts.sol";
import "../contracts/SCSeasonRewards.sol";
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
    SCSeasonRewards _seasons;

    /// 'beforeAll' runs before all other tests
    /// More special functions are: 'beforeEach', 'beforeAll', 'afterEach' & 'afterAll'
    function beforeAll() public {
        // <instantiate contract>
        _permissions = new SCPermissionsManager();

        _token = new SuperChampsToken(
            _permissions, 
            new VestingEscrowFactoryStub(),
            TestsAccounts.getAccount(0),
            TestsAccounts.getAccount(0)
        );

        _permissions.addRole(ISCPermissionsManager.Role.GLOBAL_ADMIN, address(_token));
        _token.TGE(address(this), 0);
        _token.initializeEmmissions(0);

        _seasons = new SCSeasonRewards(
            address(_permissions),
            address(_token),
            TestsAccounts.getAccount(0)
        );

        _permissions.addRole(ISCPermissionsManager.Role.TRANSFER_ADMIN, address(_seasons));
    }

    /// #sender: account-2
    function FAIL_StartSeason() public {
        try _seasons.startSeason(0, 1 ether, 1 days) {
            Assert.ok(false, "Should not have permissions!");
        } catch { 
            Assert.ok(true, "All good here.");
        }
    }
}