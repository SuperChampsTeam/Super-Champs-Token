// SPDX-License-Identifier: GPL-3.0
        
pragma solidity >=0.4.22 <0.9.0;

// This import is automatically injected by Remix
import "remix_tests.sol"; 

// This import is required to use custom transaction context
// Although it may fail compilation in 'Solidity Compiler' plugin
// But it will work fine in 'Solidity Unit Testing' plugin
import "remix_accounts.sol";
import "./VestingEscrowFactoryStub.sol";
import "../contracts/ExponentialVestingEscrow.sol";
import "../contracts/SuperChampsToken.sol";
import "../contracts/SCPermissionsManager.sol";

// File name has to end with '_test.sol', this file can contain more than one testSuite contracts
contract testSuite {
    SCPermissionsManager _permissions;
    SuperChampsToken _token;
    ExponentialVestingEscrow _escrow;

    /// 'beforeAll' runs before all other tests
    /// More special functions are: 'beforeEach', 'beforeAll', 'afterEach' & 'afterAll'
    function beforeAll() public {
        _permissions = new SCPermissionsManager();

        _token = new SuperChampsToken(
            _permissions, 
            new VestingEscrowFactoryStub(),
            TestsAccounts.getAccount(1),
            TestsAccounts.getAccount(2)
        );

        _permissions.addRole(ISCPermissionsManager.Role.GLOBAL_ADMIN, address(_token));

        _escrow = _token.questEmissions();

        _token.TGE(TestsAccounts.getAccount(3), 0);
        _token.initializeEmmissions(0);
    }

    function Day28Emissions() public {
        _escrow.TEST_spoofTimeStamp(28 days);
        Assert.ok(_escrow.unclaimed() > 1_700_242 ether && _escrow.unclaimed() < 1_700_243 ether, "Incorrect emitted");
    }

    function Day56Emissions() public {
        _escrow.TEST_spoofTimeStamp(56 days);
        Assert.ok(_escrow.unclaimed() > 3_383_479 ether && _escrow.unclaimed() < 3_383_480 ether, "Incorrect emitted");
    }

    function Day364Emissions() public {
        _escrow.TEST_spoofTimeStamp(364 days);
        Assert.ok(_escrow.unclaimed() > 20_824_219 ether && _escrow.unclaimed() < 20_824_220 ether, "Incorrect emitted");
    }

    /// #sender: account-1
    function Day28Claim() public {
        _escrow.TEST_spoofTimeStamp(28 days);
        _escrow.claim(TestsAccounts.getAccount(1),0);
        Assert.ok(_escrow.unclaimed() == 0, "Tokens not claimed!");
        Assert.ok(_escrow.locked() > 168_299_757 ether && _escrow.locked() < 168_299_758 ether, "Incorrect locked");
        Assert.ok(_escrow.locked() == _token.balanceOf(address(_escrow)), "Incorrect remaining");
        Assert.ok(_token.balanceOf(TestsAccounts.getAccount(1)) > 1_700_242 ether && _token.balanceOf(TestsAccounts.getAccount(1)) < 1_700_243 ether, "Incorrect in treasury");
    }

    /// #sender: account-1
    function Day56_ClaimToIncorrectRecipient() public {
        _escrow.TEST_spoofTimeStamp(56 days);
        try _escrow.claim(TestsAccounts.getAccount(2),0) {
            Assert.ok(false, "Request Succeeded");
        } catch { }
    }

    /// #sender: account-1
    function Day56Claim() public {
        _escrow.TEST_spoofTimeStamp(56 days);
        _escrow.claim(TestsAccounts.getAccount(1),0);
        Assert.ok(_escrow.unclaimed() == 0, "Tokens not claimed!");
        Assert.ok(_escrow.locked() > 166_616_520 ether && _escrow.locked() < 166_616_521 ether, "Incorrect locked");
        Assert.ok(_escrow.locked() == _token.balanceOf(address(_escrow)), "Incorrect remaining");
        Assert.ok(_token.balanceOf(TestsAccounts.getAccount(1)) > 3_383_479 ether && _token.balanceOf(TestsAccounts.getAccount(1)) < 3_383_480 ether, "Incorrect in treasury");
    }
}
    