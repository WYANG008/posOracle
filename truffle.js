module.exports = {
	migrations_directory: './migrations',
	networks: {
		development: {
			host: 'localhost',
			port: 8550,
			network_id: '*', // Match any network id,
			gas: 7990000
		},
		kovan: {
			host: 'localhost',
			port: 8545,
			network_id: '42', // Match any network id,
			from: '0x00BCE9Ff71E1e6494bA64eADBB54B6B7C0F5964A' // kovan
			// gas:5000000
		},
		ropsten: {
			host: 'localhost',
			port: 8560,
			network_id: '*', // Match any network id,
			from: '0x00BCE9Ff71E1e6494bA64eADBB54B6B7C0F5964A' //ropsten
			// gas:5000000
		},
		live: {
			host: 'localhost',
			port: 8545,
			network_id: '*' // Match any network id,
			// gas:5000000
		},
		coverage: {
			host: 'localhost',
			network_id: '*',
			port: 8555,
			gas: 0xfffffffffff,
			gasPrice: 0x01
		}
	}
};
