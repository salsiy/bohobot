title: "Part 5: Automating Dependency Updates with Renovate"
date: 2025-12-20
series_order: 5
series: ["Production-Grade Terraform Patterns"]
tags: ["terraform", "terragrunt", "renovate", "automation", "devops"]
---

This is the final part of our series on [Production-Grade Terraform Patterns](/series/production-grade-terraform-patterns/). We have split our repositories, enforced versioning, automated releases, and set up our consumption model.

In a traditional setup, upgrading infrastructure is painful. A developer releases `v1.1.0`, sends a Slack message, and... silence. Three months later, Prod is still on `v0.9.0`.

To build a true platform, upgrades should be **pushed to the consumer**, not pulled.

We achieve this with **Renovate Bot**.

## The Workflow

1.  **Release**: Release Please tags `v1.1.0` in your Modules Repo.
2.  **Detection**: Renovate scans your Live Repo, sees `v1.0.0`, and detects the new tag.
3.  **Proposal**: Renovate opens a Pull Request: `chore(deps): update module vpc to v1.1.0`.
4.  **Validation**: CI triggers `terragrunt plan` on that PR.
5.  **Merge**: You review the plan and merge.

## Configuring Renovate for Terragrunt

Renovate is ideal because it has a dedicated **Terragrunt Manager**. It parses HCL and finds underlying versions.

Create `renovate.json` in your Live Repo:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "config:base",
    ":dependencyDashboard"
  ],
  "enabledManagers": ["terragrunt", "terraform"],
  "terragrunt": {
    "fileMatch": ["\\.hcl$"]
  },
  "packageRules": [
    {
      "matchDatasources": ["terraform-module"],
      "groupName": "infrastructure modules",
      "labels": ["renovate/modules"]
    }
  ]
}
```

### The Dependency Dashboard

The `":dependencyDashboard"` preset prevents PR noise. Renovate creates a single GitHub Issue listing all available updates. You verify them there before checking a box to generate the actual PR.

## Validation Pipeline (CI)

A PR updating a version number is useless if you don't know what it changes.

We need a CI workflow (`.github/workflows/plan.yaml`) that runs `terragrunt run-all plan` on every PR.

```yaml
name: Terragrunt Plan
on: [pull_request]

jobs:
  plan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: hashicorp/setup-terraform@v2
      - uses: autero1/action-terragrunt@v1.3.0
      
      - name: Terragrunt Plan
        run: |
          terragrunt run-all plan --terragrunt-non-interactive -out=tfplan.binary > plan.txt
        continue-on-error: true
      
      # Step to post plan.txt as a PR comment (using github-script)
```

## Deployment Strategy: Dev vs Prod

You never want to upgrade Production at the same time as Dev. Renovate allows us to enforce "Soak Time".

Update `renovate.json` to be environment-aware:

```json
"packageRules": [
  {
    "matchPaths": ["**/dev/**"],
    "automerge": true
  },
  {
    "matchPaths": ["**/prod/**"],
    "minimumReleaseAge": "7 days"
  }
]
```

**Result**:
*   **Dev**: Updates arrive immediately. If CI passes, they can auto-merge.
*   **Prod**: Renovate waits 7 days after the release is published before even proposing the PR.

## Conclusion

We have successfully architected a self-updating platform.

1.  **Split Repos**: Separating Logic from State.
2.  **Versioning**: Pinning versions strictly.
3.  **Release Engine**: Automating releases with Release Please.
4.  **Distribution**: Using Git tags security.
5.  **Automation**: Using Renovate to drive upgrades.

This is Infrastructure as Code at the speed of software.
