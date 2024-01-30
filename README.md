# Revenue Sharing Contract
This is a modified version of the Turnstile contract from Canto: 

[https://github.com/Canto-Improvement-Proposals/CIPs/blob/main/CIP-001.md](https://github.com/Canto-Improvement-Proposals/CIPs/blob/main/CIP-001.md)


## Setup
```bash
forge install
```

## Deploy
Create `.env` file and set Ethereum RPC at `MODE_RPC_URL` and deployer private key at `PRIVATE_KEY`.

Run
```bash
source .env
forge script script/FeeSharing.s.sol:FeeSharingScript --rpc-url $MODE_RPC_URL --broadcast -vvvv
```

## Test
```bash
forge test -vvv
```
