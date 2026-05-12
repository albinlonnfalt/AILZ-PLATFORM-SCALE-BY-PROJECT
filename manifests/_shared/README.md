# Shared manifests

This folder contains platform-level metadata reused by every AI Landing Zone onboarding manifest.

| File | Purpose |
| --- | --- |
| `hub-network.json` | Describes the hub network, hub-owned private DNS resource group, hub VNet ID, and private DNS zone IDs used by onboarding networking. |
| `platform-foundry.json` | Describes the central Azure AI Foundry account, platform spoke networking, project naming prefix, and optional capability-host dependencies. |

Update these files when the shared hub network, private DNS zones, central Foundry account, or capability-host resources change. Per-workload settings belong in `manifests/<appid>/`.
