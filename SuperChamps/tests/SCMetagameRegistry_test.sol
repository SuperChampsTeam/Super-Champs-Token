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

        _permissions.addRole(ISCPermissionsManager.Role.METAGAME_SYSTEM, 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4);
        _permissions.addRole(ISCPermissionsManager.Role.METAGAME_SYSTEM, TestsAccounts.getAccount(1));
    }

    /// #sender: account-1
    function RegisterData() public {
        _metadata.TEST_overrideSender(TestsAccounts.getAccount(1));
        _metadata.registerUserInfo(
            "TEST_USER",
            TestsAccounts.getAccount(2),
            "TEST_KEY",
            "TEST_VALUE",
            0,
            0,
            bytes("")
        );

        string memory metadata = _metadata.metadataFromUserID("TEST_USER", "TEST_KEY");
        Assert.ok(keccak256(abi.encodePacked(metadata)) == keccak256(abi.encodePacked("TEST_VALUE")), "");
    }

    /// #sender: account-2
    function FAIL_RegisterData() public {   
        _metadata.TEST_overrideSender(TestsAccounts.getAccount(2));

        try _metadata.registerUserInfo(
            "TEST_USER",
            TestsAccounts.getAccount(3),
            "TEST_KEY",
            "TEST_VALUE_2",
            0,
            0,
            bytes("")
        ) {
            Assert.ok(false, "Request Succeeded");
        } catch { }

        string memory metadata = _metadata.metadataFromUserID("TEST_USER", "TEST_KEY");
        Assert.ok(keccak256(abi.encodePacked(metadata)) == keccak256(abi.encodePacked("TEST_VALUE")), "");
    }    
}
    