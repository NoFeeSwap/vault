
// autogenerated by brownie
// do not modify the existing settings
module.exports = {
  networks: {
      hardhat: {
          hardfork: "cancun",
          // base fee of 0 allows use of 0 gas price when testing
          initialBaseFeePerGas: 0,
          // brownie expects calls and transactions to throw on revert
          throwOnTransactionFailures: true,
          throwOnCallFailures: true
     }
  }
}