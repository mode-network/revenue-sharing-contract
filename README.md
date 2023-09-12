# revenue-sharing-contract
This is a modified version of the Turnstile contract from Canto
```https://github.com/Canto-Improvement-Proposals/CIPs/blob/main/CIP-001.md```

## Setup
`forge install`

## Deploy
Create `.env` file and set Ethereum RPC at `MODE_RPC_URL` and deployer private key at `PRIVATE_KEY`.

Run
```
source .env
forge script script/Turnstile.s.sol:TurnstileScript --rpc-url $MODE_RPC_URL --broadcast -vvvv
```

## Test
`forge test -vvv`
