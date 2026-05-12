# Finance PoC - LDEl (App ID: 1001)

## Summary
This request creates an AI Landing Zone instance to run a finance proof-of-concept that evaluates whether AI agents can read and write financial reports.

## Requested environment
- App ID: 1001
- Azure subscription: 9854418d-ea0c-4ed7-a2b6-e4597b2da7b3
- GitHub organization: albinlonnfalt
- Location: swedencentral (default)
- Environment: proof-of-concept

## What will be provisioned
- Baseline AI Landing Zone (Microsoft Foundry access and onboarding metadata).
- No optional workload services (search, Cosmos DB, Storage, Key Vault) are enabled by default.

## Defaults used
- Location: swedencentral (from manifests README)
- Environment tag: proof-of-concept
- baseName: ai-lz
- All optional feature flags left at reference defaults (disabled)

## Reviewer notes
- Azure subscription ID was provided in the triggering content.
- No optional services or capability host names were requested; feature flags remain disabled.
- Data classification, networking (private endpoints), and required user access were not specified.
