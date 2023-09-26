

## Documentation
This repository uses [Foundry](https://book.getfoundry.sh/") as smart-contract development framework.

## Locker.sol  
This contract is used to deposit MAV tokens on Rogue.
- Depositors receive rMAV tokens at a 1:1 ratio.
- Depositors can withdraw MAV until a pre-announced date.
- rMAV adheres to the Layer Zero OFT standard.
- Anybody can call `lock` to extend the lockup and receive rMAV tokens as incentive.


## Usage

### To build

```shell
$ forge build
```

### To test

```shell
$ forge test
```

### To get coverage

```shell
$ forge coverage
```


