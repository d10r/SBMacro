## SB Macro

This is a Macro contract which provides a convenient API for SuperBoring.

### Why Macro?

What's the point of a Macro?
1. A Dapp could just have a normal contract which is invoked.
But then msg.sender wouldn't be preserved. And it can't do a sender preserving forward call bcs not a trusted forwarder
2. A Dapp could just compile the needed calldata and do a batchOperation itself, without intermediate contract.
Yes, but that can be much more effort, also it's not atomic. So state it reads & assumes could have change when executed.

The macro allows preserving sender while having a convenient API and atomicity.

### Usage

The macro contract is invoked by a pre-existing [MacroForwarder](https://github.com/superfluid-finance/protocol-monorepo/blob/dev/packages/ethereum-contracts/contracts/utils/MacroForwarder.sol) contract. This contract is registered as a `trusted forwarder` of the Superfluid protocol.
It's currently available at address `0xFd017DBC8aCf18B06cff9322fA6cAae2243a5c95` on Optimisim Sepolia Testnet and Base Mainnet.

First, an instance of `SBMacro` needs to be deployed. This can be done with
```
forge create ... src/SBMacro.sol:SBMacro
```

Now the account which wants to use Superboring needs to do a transaction, using the MacroForwarder as entry point.
Example using Solidity:
```
macroFwd.runMacro(sbMacroAddr, abi.encode(torexAddr, flowRate, distributor, referrer, upgradeAmount));
```

Example using JS with ethers v6:
```
macroFwd.runMacro(sbMacroAddr, ethers.AbiCoder.defaultAbiCoder().encode(['address', 'int96', 'address', 'address', 'uint256'], [torexAddr, flowRate, distributor, referrer, upgradeAmount]));
```

Instead of using a client-side library to get encoded parameters, you can also use the convenience function `getParams()`.
For example in a JS App:
```
macroFwd.runMacro(sbMacroAddr, await sbMacro.getParams(torexAddr, flowRate, distributor, referrer, upgradeAmount));
```

For more details about the arguments, see the contract documentation.

### Limitations

- Transaction will fail if there's no free slot for connecting `outTokenDistributionPool`.