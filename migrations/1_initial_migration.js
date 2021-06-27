const EscrowTrade = artifacts.require("EscrowTrade");

const name = 'custom Token';
const symbol = 'CT';

module.exports = function(deployer) {

  deployer.deploy(EscrowTrade);

};
