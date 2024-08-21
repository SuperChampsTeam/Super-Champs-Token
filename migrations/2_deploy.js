// migrations/2_deploy.js
const SCDeploymentHelper = artifacts.require('SCDeploymentHelper');
const SCRewardsDispenser = artifacts.require('SCRewardsDispenser');
const SCAccessPass = artifacts.require('SCAccessPass');
const SCSeasonRewards = artifacts.require('SCSeasonRewards');
const PermissionsManager = artifacts.require('PermissionsManager');
const SuperChampsToken = artifacts.require('SuperChampsToken');
const ExponentialVestingEscrow = artifacts.require('ExponentialVestingEscrow');
const SCMetaGamePool = artifacts.require('SCMetaGamePool');

var superchampFoundationAddress = "0x62500Df60073E22C5FF833ae855F7922Bb4c0A88" //ATTENTION: update in SCDeploymentHelper contract also. 
var sysAdminKmsAddress = "0xb5B968c31832800eCfedebb05fE1Fe741d387BF4"
var emissionATreasury = "0x2Af9a14bcA18A21eD9ADC08Bbf99b93977F0Ad73"
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
  console.log("scRewardsDispenser deployed " + scRewardsDispenser.address);

  await deployer.deploy(SCAccessPass, pAddress, "SBT", "SBT", "https://champs-metadata.onjoyride.com/tc-genesis/tokens/revealed");
  const scAccessPass = await SCAccessPass.deployed();
  console.log("scAccessPass deployed " + scAccessPass.address);

  //todo: Vested Token Allocations section of https://docs.google.com/document/d/1uMl_cJhMeJL0ND6i7eMOf73JtRQ5qnMTpeyNra343yI/edit#heading=h.gll6bjs55xo8

  const permissionsManager = await PermissionsManager.at(pAddress);
  console.log("permissionsManager")
  const receipt = await permissionsManager.addRole(4, sysAdminKmsAddress, { from: superchampFoundationAddress }) //    await permissionsManagerInstance.addRole(role, accountToAdd, { from: accounts[0] }); // Use appropriate account as the sender
  console.log("permissionsManager sys admin success");

  const receipt1 = await permissionsManager.addRole(3, sysAdminKmsAddress, { from: superchampFoundationAddress }) //    await permissionsManagerInstance.addRole(role, accountToAdd, { from: accounts[0] }); // Use appropriate account as the sender
  console.log("permissionsManager transfer admin success");
  
  const transferLockERC20 = await SuperChampsToken.at(tokenAddress);
  console.log("transferLockERC20");
  var BN = web3.utils.BN;
  const approveAmount = new BN('230000000000000000000000000');
  const receipt2 = await transferLockERC20.approve(scDeploymentHelperAddress, approveAmount, { from: superchampFoundationAddress }) //todo review amount //todo not full sure whether this code will actually  perform tx from superchampFoundationAddress address
  console.log("transferLockERC20 success")


  console.log("scDeploymentHelper.initializeEmission calling")
  const thirtyDayInPastForQuestEmission = Math.floor(Date.now() / 1000) - (29*30*24*3600)
  const emissionATreasuryAmount = new BN('115000000000000000000000000');
  const emissionContractDeploymentAddress = await scDeploymentHelper.initializeEmmissions.call(emissionATreasury, emissionATreasuryAmount, thirtyDayInPastForQuestEmission, { from: superchampFoundationAddress }) //todo review amount
  console.log("emissionContractDeploymentAddress: " + emissionContractDeploymentAddress);
  const emissionReceipt = await scDeploymentHelper.initializeEmmissions(emissionATreasury, emissionATreasuryAmount, thirtyDayInPastForQuestEmission, { from: superchampFoundationAddress }) //todo review amount
  console.log("scDeploymentHelper.initializeEmission success reciept :")
  console.log(emissionReceipt)
  const txDetails = await web3.eth.getTransaction(emissionReceipt.tx);
  console.log('scDeploymentHelper.initializeEmission tx details:');
  console.log(txDetails);

  await deployer.deploy(SCMetaGamePool, pAddress, tokenAddress);
  const scMetaGamePool = await SCMetaGamePool.deployed();
  console.log("SCMetaGamePool deployed " + scMetaGamePool.address);

  await deployer.deploy(SCSeasonRewards, pAddress, tokenAddress, treasuryForSeason, scAccessPass.address, scMetaGamePool.address);
  const scSeasonRewards = await SCSeasonRewards.deployed();
  console.log("scSeasonRewards deployed " + scSeasonRewards.address);

  const exponentialVestingEscrow = await ExponentialVestingEscrow.at(emissionContractDeploymentAddress);
  const unclaimedAmount = await exponentialVestingEscrow.unclaimed();
  console.log("unclaimedAmount: " + unclaimedAmount);

  const claimedAmountTx = await exponentialVestingEscrow.claim(treasuryForSeason, unclaimedAmount);
  console.log("claimedAmountTx success reciept :")
  console.log(claimedAmountTx)
  const claimedAmountTxDetails = await web3.eth.getTransaction(claimedAmountTx.tx);
  console.log('claimedAmountTx tx details:');
  console.log(claimedAmountTxDetails);


  const receipt3 = await transferLockERC20.approve(scSeasonRewards.address, emissionATreasuryAmount, { from: treasuryForSeason }) //todo review amount //todo not full sure whether this code will actually  perform tx from superchampFoundationAddress address
  console.log("transferLockERC20 approve receipt3 success to contract scSeasonRewards")


  const receipt4 = await permissionsManager.addRole(3, scSeasonRewards.address, { from: superchampFoundationAddress }) //    await permissionsManagerInstance.addRole(role, accountToAdd, { from: accounts[0] }); // Use appropriate account as the sender
  console.log("permissionsManager transfer admin success to contract scSeasonRewards");

  const receipt5 = await permissionsManager.addRole(3, scMetaGamePool.address, { from: superchampFoundationAddress }) //    await permissionsManagerInstance.addRole(role, accountToAdd, { from: accounts[0] }); // Use appropriate account as the sender
  console.log("permissionsManager transfer admin success to contract scMetaGamePool");


  //todo : implement from `FACTORY.initializeEmmissions is called by Foundation Multisig for Metagame system` part of  https://docs.google.com/document/d/1uMl_cJhMeJL0ND6i7eMOf73JtRQ5qnMTpeyNra343yI/edit#heading=h.gll6bjs55xo8
};
