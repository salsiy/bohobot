---
title: "Part 5: Automating Dependency Updates with Renovate"
date: 2026-01-05
series_order: 5
series: ["Production-Grade Terraform Patterns"]
tags: ["terraform", "terragrunt", "renovate", "automation", "devops"]
draft: false
---

This is Part 5 of my series on [Production-Grade Terraform Patterns](/series/production-grade-terraform-patterns/). I have split my repositories, enforced versioning, automated releases, and set up my consumption model.

In a traditional setup, upgrading infrastructure is painful. A developer releases `vpc-v1.1.0`, sends a Slack message, and... silence. Three months later, Prod is still on `vpc-v0.9.0`.

To build a robust infrastructure, upgrades should be **pushed to the consumer**, not pulled.

I achieve this with **Renovate Bot**.

## The Workflow

1.  **Release**: Release Please tags `vpc-v1.1.0` in your Modules Repo.
2.  **Detection**: Renovate scans your Live Repo, sees `vpc-v1.0.0`, and detects the new tag.
3.  **Proposal**: Renovate opens a Pull Request: `chore(deps): update module vpc to vpc-v1.1.0`.
4.  **Validation**: CI triggers `terragrunt plan` on that PR.
5.  **Merge**: You review the plan and merge.

{{< mermaid >}}
graph TD
    Tag[New Tag vpc-v1.1.0 Released] -->|Scanned by| Reno[Renovate Bot]
    
    subgraph Live_Repo [Live Infrastructure Repo]
        Reno -->|Opens PR| PR[PR: Update to vpc-v1.1.0]
    end
    
    subgraph CI_Pipeline [GitHub Actions]
        PR -->|Triggers| Plan[terragrunt run-all plan]
        Plan -->|Posts Comment| PR
    end
    
    eng[Engineer] -->|Reviews Plan| PR
    eng -->|Merges| Live_Repo
    
    Live_Repo -->|Apply| AWS[AWS Cloud]

    style Reno fill:#00796b,stroke:#004d40,color:white
    style PR fill:#ffecb3,stroke:#ff6f00
    style AWS fill:#232f3e,stroke:#ff9900,color:white
{{< /mermaid >}}

A real Renovate pull request looks like this in GitHub:

![Renovate PR proposing a module version bump](/images/post/part-5-renovate-pr.png)

## Configuring Renovate for Terragrunt

Renovate is ideal because it has a dedicated **Terragrunt manager**. It parses HCL and finds underlying versions.

Here is the **`renovate.json`** from my live repo, [terraform-patterns-live](https://github.com/salsiy/terraform-patterns-live) ([source on GitHub](https://github.com/salsiy/terraform-patterns-live/blob/main/renovate.json)):

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "config:recommended",
    ":dependencyDashboard"
  ],
  "enabledManagers": [
    "terragrunt",
    "terraform"
  ],
  "terragrunt": {
    "managerFilePatterns": [
      "/\\.hcl$/"
    ],
    "versioning": "regex:^((?<compatibility>.*)-v|v*)(?<major>\\d+)\\.(?<minor>\\d+)\\.(?<patch>\\d+)$"
  },
  "packageRules": [
    {
      "matchDatasources": [
        "git-tags",
        "github-tags",
        "terraform-module"
      ],
      "groupName": "infrastructure modules",
      "matchPackageNames": [
        "/terraform-patterns-modules/"
      ]
    },
    {
      "matchFileNames": [
        "**/development-account/**"
      ],
      "automerge": true
    },
    {
      "matchFileNames": [
        "**/production-account/**"
      ],
      "minimumReleaseAge": "7 days"
    }
  ]
}
```

* **`config:recommended`** plus **`:dependencyDashboard`** gives sensible defaults and a single GitHub Issue that lists pending updates.
* **`terragrunt.managerFilePatterns`** limits scanning to `.hcl` files; the **`versioning`** regex matches tags like `vpc-v1.2.0` from this series (compatibility prefix + semver).
* **`packageRules`**: module updates under `terraform-patterns-modules` are **grouped** as “infrastructure modules”; paths under **`development-account`** may **automerge** when CI passes; **`production-account`** changes wait **7 days** after release before Renovate proposes them (`minimumReleaseAge`).

### The Dependency Dashboard

The `":dependencyDashboard"` preset prevents PR noise. Renovate creates a single GitHub Issue listing all available updates. You verify them there before checking a box to generate the actual PR.

## Validation Pipeline (CI)

A PR updating a version number is useless if you don't know what it changes.

I need a CI workflow (`.github/workflows/plan.yaml`) that runs `terragrunt run-all plan` on every PR.

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

## Deployment strategy: dev vs prod

You rarely want production to move at the same pace as development. In the config above, **`matchFileNames`** ties behavior to your repo layout: anything under **`development-account`** can **automerge** after CI; anything under **`production-account`** must pass a **7-day** `minimumReleaseAge` before Renovate opens a PR, which gives a soak period on new module releases.

Adjust the path globs to match your own account or folder names. The idea is the same: **fast feedback in lower environments**, **slower, explicit promotion** toward production.

## Moving to execution

You now have a pipeline that proposes updates automatically. But who *approves* and *applies* them?

If you merge a PR, does a human run `terraform apply`? In **Part 6**, I will introduce **TACOS (Atlantis, Digger)** to automate the final mile of execution safely.
