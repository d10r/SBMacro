## SB Macro

This is a Macro contract which provides a convenient API for easy onboarding to SuperBoring.
Running this macro will create a DCA flow to a SuperBoring Torex according to the provided parameters.
The following parameters can be set:
- Torex address (determines the Super Token to be sent)
- Flowrate of the flow being created to the Torex
- Distributor (optional, can be zero)
- Referrer (optional, can be zero)
- Upgrade amount (optional, can be 0)

For more details about the arguments, see the contract documentation.

### Usage

The macro contract is invoked by a pre-existing [MacroForwarder](https://github.com/superfluid-finance/protocol-monorepo/blob/dev/packages/ethereum-contracts/contracts/utils/MacroForwarder.sol) contract. This contract is registered as a `trusted forwarder` of the Superfluid protocol.
Check [the console](https://console.superfluid.finance/protocol) for MacroForwarder deployment addresses.

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

### Why a Macro?

What's the point of a Macro?
1. A Dapp could just have a normal contract which is invoked.
But then msg.sender wouldn't be preserved. And it can't do a sender preserving forward call bcs not a trusted forwarder
2. A Dapp could just compile the needed calldata and do a batchOperation itself, without intermediate contract.
Yes, but that can be much more effort, also it's not atomic. So state it reads & assumes could have change when executed.

The macro allows preserving sender while having a convenient API and atomicity.


### Limitations

- Transaction will fail if there's no free slot for connecting `outTokenDistributionPool`.