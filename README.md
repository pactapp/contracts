## PACT's Bank Contracts

Bank contract to deposit and lock in user funds.

### Design philosophy

- USDC is the money
- Internal shares track ownership
- No external reward distribution loops
- Penalties increase share value for everyone else

### High-level mechanics

1. User deposits USDC
2. Set a goal for savings timing. 30 days, 60 days etc
3. They receive internal "shares" (ERC-4626 style)
4. Shares represent a portion of the pool
   - 10% penalty on withdrawing before the lockup expires
   - 90% Penalty stays
   - Remaining users benifits automatically

### Invariants

**Shares** - The percentage ownership of the USDC stored inside the vault. We use something similar to ERC-4626 without handling out ERC20 tokens. We use this for internal accounting.

- totalAssets >= 0
- totalShares >= 0

- sharePrice = totalAssets / totalShares

Where `sharePrice` determine the amount of USDC user receives after post unlock withdrawing
and `totalAssets` is the total amount of USDC inside the contracy and `totalShares` issued by the contract.
