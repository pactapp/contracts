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
   - 10% penalty
   - Penalty stays in the pool
   - Remaining users benifits automatically
