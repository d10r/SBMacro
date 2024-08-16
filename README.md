## SB Macro

This is a Macro contract which provides a convenient API for SuperBoring.

### Why Macro?

What's the point of a Macro?
1. A Dapp could just have a normal contract which is invoked.
But then msg.sender wouldn't be preserved. And it can't do a sender preserving forward call bcs not a trusted forwarder
2. A Dapp could just compile the needed calldata and do a batchOperation itself, without intermediate contract.
Yes, but that can be much more effort, also it's not atomic. So state it reads & assumes could have change when executed.

The macro allows preserving sender while having a convenient API and atomicity.
