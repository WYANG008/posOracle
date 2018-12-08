const web3 = require('web3');
const SafeMath = artifacts.require('./SafeMath.sol');
const Oracle = artifacts.require('./Oracle.sol');
// const DOT = artifacts.require('./DOT.sol');
const InitParas = require('./contractInitParas.json');
const DOTinit = InitParas['DOT'];
const OracleInit = InitParas['Oracle'];

module.exports = async (deployer, network, accounts) => {
	let creator = "0x00BCE9Ff71E1e6494bA64eADBB54B6B7C0F5964A";

	if (network == 'development' || network == 'coverage') {
		creator = accounts[0];
	}

	await deployer.deploy(SafeMath, {
			from: creator
		});
		await deployer.link(SafeMath, Oracle);

	await deployer.deploy(
		Oracle,
		OracleInit.pd,
		OracleInit.openWindow,
		DOTinit.tokenName,
		DOTinit.tokenSymbol,
		web3.utils.toWei(DOTinit.initSupply, 'ether'),
		{
			from: creator
		}
	);
};


