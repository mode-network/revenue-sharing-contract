# revenue-sharing-contract
This is a modified version of the Turnstile contract from Canto
```https://github.com/Canto-Improvement-Proposals/CIPs/blob/main/CIP-001.md```

## Setup
`forge install`

## Deploy
Copy the `.env.testnet` or `.env.mainnet` file to `.env` and set the deployer private key at `PRIVATE_KEY`.

Run
```
source .env
forge script script/FeeSharing.s.sol:FeeSharingScript --rpc-url $MODE_RPC_URL --broadcast -vvvv
```

Or, use this command to also get the contract verified after deployment
```
forge create --rpc-url  $MODE_RPC_URL --private-key $PRIVATE_KEY src/FeeSharing.sol:FeeSharing --verify --verifier blockscout --verifier-url $EXPLORER_URL

```

## Test
`forge test -vvv`
