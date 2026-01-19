---
title: "Part 3: Automating Semantic Versioning with Release Please"
date: 2025-12-20
series_order: 3
series: ["Production-Grade Terraform Patterns"]
tags: ["terraform", "release-please", "github-actions", "cicd", "automation"]
draft: false
---

This is Part 3 of my series on [Production-Grade Terraform Patterns](/series/production-grade-terraform-patterns/). In [Part 2](/posts/tech-logs/part-2-production-ready-modules/), I established standards for module creation. Now, I solve the biggest friction point in module management: **Release Engineering**.

> **Prerequisite**: This guide assumes you have defined your modules using the **Production-Ready Standards** from [Part 2](/posts/tech-logs/part-2-production-ready-modules/).

Treating infrastructure as software means you must version it. But if an engineer updates a module, they shouldn't have to manually calculate semantic versions ("Is this a minor or patch?"), write changelogs, or tag releases.

In high-velocity teams, manual release steps lead to:
1.  **"Big Bang" Releases**: Engineers delay releases to avoid the hassle, batching weeks of changes.
2.  **Unstable References**: People reference `main` because there isn't a recent tag, breaking production reliability.

The solution is to automate this entire lifecycle using **Release Please**.

## Why Release Please?

There are many tools for this (like [semantic-release](https://github.com/semantic-release/semantic-release)), and any of them can work depending on your preference.

The critical point is that **manually managing and calculating tags is difficult**. I choose **[Release Please](https://github.com/googleapis/release-please-action)** because:

1.  **Google-Backed**: It is maintained by Google.
2.  **Easy Integration**: It integrates seamlessly with GitHub Actions, automating the complex task of versioning without requiring heavy custom scripting.

## The Strategy: Conventional Commits

Automation requires structured data. You cannot automate versioning if commit messages are "fixed stuff" or "updated vpc".

I adopt **[Conventional Commits](https://www.conventionalcommits.org/)**:

| Prefix | SemVer Impact | Example | Result |
| :--- | :--- | :--- | :--- |
| `fix:` | Patch (0.0.x) | `fix(vpc): correct typo in subnet tag` | 1.0.0 -> 1.0.1 |
| `feat:` | Minor (0.x.0) | `feat(eks): add fargate support` | 1.0.0 -> 1.1.0 |
| `feat!:` | Major (x.0.0) | `feat!(s3): force encryption` | 1.0.0 -> 2.0.0 |

The `!` indicates a breaking change (Major), regardless of the prefix.

## Configuring Release Please in a Monorepo

I often keep multiple modules in one repository (a Monorepo). A change to the VPC module should not trigger a release for the RDS module.

Release Please uses a **Manifest-Driven** approach to handle this.

### 1. The State: `.release-please-manifest.json`

This file tracks the current version of every component.

```json
{
  "modules/vpc": "1.0.0",
  "modules/eks-cluster": "2.1.0"
}
```

### 2. The Configuration: `release-please-config.json`

This defines the strategy. I use the `terraform-module` type, which knows how to update Terraform files and READMEs.

```json
{
  "packages": {
    "modules/vpc": {
      "release-type": "terraform-module",
      "package-name": "aws-vpc-module",
      "changelog-path": "CHANGELOG.md"
    },
    "modules/eks-cluster": {
      "release-type": "terraform-module",
      "package-name": "aws-eks-cluster-module"
    }
  }
}
```

## The Workflow: GitHub Actions

I create a workflow `.github/workflows/release.yaml`.

This workflow utilizes a specific pattern: **The Persistent Release PR**.
When you merge a `feat:` into `main`, Release Please doesn't release immediately. It opens (or updates) a dedicated "Release PR". This PR contains the calculated Changelog and version bump.

The release is only "cut" when you merge this specific Release PR.

```yaml
name: Release Please
on:
  push:
    branches:
      - main

jobs:
  release-please:
    runs-on: ubuntu-latest
    steps:
      - uses: google-github-actions/release-please-action@v4
        with:
          config-file: release-please-config.json
          manifest-file: .release-please-manifest.json
          token: ${{ secrets.GITHUB_TOKEN }}
```

## Internal Version Files

Standard Terraform doesn't have a `package.json` with a version field. To let our Terraform code know its own version (e.g., for tagging resources), I use a generic internal file.

In `modules/vpc/versions.tf`:

```hcl
locals {
  # x-release-please-version
  version = "1.0.0"
}
```

I update `release-please-config.json` to target this file:

```json
"extra-files": [
  {
    "type": "generic",
    "path": "modules/vpc/versions.tf",
    "jsonpath": "locals.version"
  }
]
```

Now, Release Please will automatically bump this local variable whenever it cuts a release.

{{< mermaid >}}
sequenceDiagram
    participant Dev as Developer
    participant Main as Main Branch
    participant RP as Release Please (Bot)
    participant PR as Release PR
    participant Tag as Git Tag

    Dev->>Main: git commit -m "feat: new vpc"
    activate Main
    Main->>RP: Trigger Action
    deactivate Main
    activate RP
    RP->>RP: Analyze Commits (feat = minor)
    RP->>PR: Open/Update "chore: release 1.1.0"
    deactivate RP
    
    Note over PR: Contains CHANGELOG.md<br/>and version bumps
    
    Dev->>PR: Review & Merge
    activate PR
    PR->>Main: Merge Pull Request
    deactivate PR
    
    activate Main
    Main->>RP: Trigger Action (on Merge)
    deactivate Main
    activate RP
    RP->>Tag: Create Tag v1.1.0
    RP->>RP: Publish GitHub Release
    deactivate RP
{{< /mermaid >}}

## Summary

This workflow transforms the developer experience:

1.  **Code**: Engineer commits `feat: add private subnet`.
2.  **Merge**: PR merged to main.
3.  **Propose**: Release Please opens a PR: "chore: release modules/vpc 1.1.0".
4.  **Release**: Team Lead merges that PR.
5.  **Publish**: Tag is created, Release is published.

I now have strictly versioned, immutable artifacts. In **Part 4**, I will decide how to consume these artifacts: via simple Git Tags or a Private Registry.