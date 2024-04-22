// SPDX-License-Identifier: GPL-3.0
        
pragma solidity >=0.4.22 <0.9.0;

// This import is automatically injected by Remix
import "remix_tests.sol"; 

// This import is required to use custom transaction context
// Although it may fail compilation in 'Solidity Compiler' plugin
// But it will work fine in 'Solidity Unit Testing' plugin
import "remix_accounts.sol";
import "../contracts/SCPermissionsManager.sol";
import "../contracts/SCMetagameRegistry.sol";

// File name has to end with '_test.sol', this file can contain more than one testSuite contracts
contract testSuite {
    SCPermissionsManager _permissions;
    SCMetagameRegistry _metadata;

    /// 'beforeAll' runs before all other tests
    /// More special functions are: 'beforeEach', 'beforeAll', 'afterEach' & 'afterAll'
    function beforeAll() public {
        _permissions = new SCPermissionsManager();

        _metadata = new SCMetagameRegistry(
            address(_permissions)
        );
    }

    function verifyPermissions() public {
        Assert.ok(!_permissions.hasRole(ISCPermissionsManager.Role.METAGAME_SYSTEM, TestsAccounts.getAccount(1)), "Should not have role");
        _permissions.addRole(ISCPermissionsManager.Role.METAGAME_SYSTEM, TestsAccounts.getAccount(1));
        Assert.ok(_permissions.hasRole(ISCPermissionsManager.Role.METAGAME_SYSTEM, TestsAccounts.getAccount(1)), "Should have role");
    }
}