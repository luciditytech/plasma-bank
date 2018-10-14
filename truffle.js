require('babel-register');
require('babel-polyfill');

module.exports = {
  networks: {
    development: {
      host: 'localhost',
      port: 8545,
      network_id: '*'
    },
    staging: {
      host: '172.31.80.135',
      port: 8545,
      network_id: '*',
      gas: 4600000
    },
    production: {
      host: '172.31.80.135',
      port: 8545,
      network_id: '*',
      gas: 4600000
    },
    coverage: {
      host: 'localhost',
      network_id: '*',
      port: 8555,
      gas: 0xfffffffffff,
      gasPrice: 0x01
    },
  }
};
