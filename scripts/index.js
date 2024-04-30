// scripts/index.js

const SCSeasonRewards = artifacts.require('SCSeasonRewards');
var sysAdminKmsAddress = "0x22d491Bde2303f2f43325b2108D26f1eAbA1e32b" //ATTENTION:same as deploy.js

module.exports = async function main (callback) {
    try {
      // Our code will go here

      //test scSeasonRewards
      const scSeasonRewards = await SCSeasonRewards.deployed();
      console.log("scSeasonRewards deployed ");
      const startSeasonReceipt = await scSeasonRewards.startSeason( Math.floor(Date.now() / 1000) + 5, { from: sysAdminKmsAddress })
      console.log("startSeasonReceipt success")
      const endSeasonReceipt = await scSeasonRewards.endSeason(0, { from: sysAdminKmsAddress })
      console.log("endSeasonReceipt success")

     
  
      callback(0);
    } catch (error) {
      console.error(error);
      callback(1);
    }
  };
