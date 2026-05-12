# AI Landing Zone Manifests

The `manifests` folder contains one folder per onboarded AI Landing Zone instance:

```text
manifests/
└── <appid>/
    ├── main-parameters.json
    └── meta-data-onboarding.json
```

Start from `manifests/example` when adding a new instance.

## Files

| File | Purpose |
| --- | --- |
| `meta-data-onboarding.json` | Target subscription, app ID, and GitHub organization for onboarding. |
| `main-parameters.json` | ARM parameters copied into the downstream workload repository. Use it for location, tags, feature flags, DNS behavior, and optional developer RBAC. |

The onboarding workflow combines the per-app manifest with `manifests/_shared/hub-network.json` and `manifests/_shared/platform-foundry.json`. Terraform then creates the downstream repository, deployment identity, spoke network outputs, and one central Foundry project for the APPID.

## Add A Manifest

1. Create `manifests/<appid>/`.
2. Copy both files from `manifests/example`.
3. Update `meta-data-onboarding.json`:

   ```json
   {
     "subscription-id": "<azure-subscription-id>",
     "app-id": "<appid>",
     "github-org": "<github-organization>"
   }
   ```

4. Update `main-parameters.json` for the instance.
5. Validate both files as JSON.
6. Run the **Onboard AI Landing Zone** workflow with `manifests/<appid>`.

## Keep In Mind

- The folder name must match `app-id`.
- Keep `baseName`, `location`, and `tags` intentional and Azure-name-safe.
- Set feature flags deliberately, especially `deployContainerApps` and `manageDnsZoneGroups`.
- Leave `deployerPrincipalId` empty unless developer RBAC should be assigned to enabled workload resources.
- Do not add generated values such as VNet IDs, subnet IDs, Private DNS zone IDs, `appName`, or `foundryProjectId` to the per-app manifest. Onboarding publishes those values downstream.
- Make sure the shared hub networking and platform Foundry files are current before onboarding.
