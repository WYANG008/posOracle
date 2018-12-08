var Migrations = artifacts.require('./Migrations.sol');

module.exports = function(deployer, network, accounts) {

	switch (network){
		case "kovan": 
			deployer.deploy(Migrations, {from: "0x00BCE9Ff71E1e6494bA64eADBB54B6B7C0F5964A"});
			break;
		case "live":
			deployer.deploy(Migrations, {from: accounts[0]});
			break;
		default:
			deployer.deploy(Migrations, {from: accounts[0]});
			break;
	}	
};
