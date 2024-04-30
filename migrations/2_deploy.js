// migrations/2_deploy.js
const SCDeploymentHelper = artifacts.require('SCDeploymentHelper');
const SCRewardsDispenser = artifacts.require('SCRewardsDispenser');
const SCAccessPass = artifacts.require('SCAccessPass');
const SCSeasonRewards = artifacts.require('SCSeasonRewards');
const PermissionsManager = artifacts.require('PermissionsManager');
const TransferLockERC20 = artifacts.require('TransferLockERC20');


var superchampFoundationAddress = "0xE11BA2b4D45Eaed5996Cd0823791E0C93114882d" //ATTENTION: update in SCDeploymentHelper contract also. 
var sysAdminKmsAddress = "0x22d491Bde2303f2f43325b2108D26f1eAbA1e32b"
var emissionATreasury = "0xFFcf8FDEE72ac11b5c542428B35EEF5769C409f0"
var treasuryForQuest = emissionATreasury
var treasuryForSeason = treasuryForQuest

module.exports = async function (deployer) {

  await deployer.deploy(SCDeploymentHelper);
  const scDeploymentHelper = await SCDeploymentHelper.deployed();
  const scDeploymentHelperAddress = scDeploymentHelper.address;


  const tokenAddress = await scDeploymentHelper.getERC20Address()
  console.log("tokenAddress " + tokenAddress);

  const pAddress = await scDeploymentHelper.getPermissionManagerAddress()
  console.log("pAddress " + pAddress);

  await deployer.deploy(SCRewardsDispenser, pAddress, tokenAddress);
  const scRewardsDispenser = await SCRewardsDispenser.deployed();
  console.log("scRewardsDispenser deployed ");

  await deployer.deploy(SCAccessPass, pAddress, "SBT", "SBT", "https://champs-metadata.onjoyride.com/tc-genesis/tokens/revealed/1");
  const scAccessPass = await SCAccessPass.deployed();
  console.log("scAccessPass deployed ");

  //todo: Vested Token Allocations section of https://docs.google.com/document/d/1uMl_cJhMeJL0ND6i7eMOf73JtRQ5qnMTpeyNra343yI/edit#heading=h.gll6bjs55xo8

  const permissionsManager = await PermissionsManager.at(pAddress);
  console.log("permissionsManager")
  const receipt = await permissionsManager.addRole(4, sysAdminKmsAddress, { from: superchampFoundationAddress }) //    await permissionsManagerInstance.addRole(role, accountToAdd, { from: accounts[0] }); // Use appropriate account as the sender
  console.log("permissionsManager success")

  const transferLockERC20 = await TransferLockERC20.at(tokenAddress);
  console.log("transferLockERC20")
  const receipt1 = await transferLockERC20.approve(scDeploymentHelperAddress, 230000000, { from: superchampFoundationAddress }) //todo review amount //todo not full sure whether this code will actually  perform tx from superchampFoundationAddress address
  console.log("transferLockERC20 success")


  console.log("scDeploymentHelper.initializeEmission calling")
  const thirtyDayInPastForQuestEmission = Math.floor(Date.now() / 1000) - (30*24*3600)
  const emissionReceipt = await scDeploymentHelper.initializeEmmissions(emissionATreasury, 115000000, thirtyDayInPastForQuestEmission, { from: superchampFoundationAddress }) //todo review amount
  console.log("scDeploymentHelper.initializeEmission success " + emissionReceipt.tx)
  const txDetails = await web3.eth.getTransaction(emissionReceipt.tx);
  console.log('scDeploymentHelper.initializeEmission tx details:' + txDetails);

  await deployer.deploy(SCSeasonRewards, pAddress, tokenAddress, treasuryForSeason);
  const scSeasonRewards = await SCSeasonRewards.deployed();
  console.log("scSeasonRewards deployed ");



  //todo : implement from `FACTORY.initializeEmmissions is called by Foundation Multisig for Metagame system` part of  https://docs.google.com/document/d/1uMl_cJhMeJL0ND6i7eMOf73JtRQ5qnMTpeyNra343yI/edit#heading=h.gll6bjs55xo8
};