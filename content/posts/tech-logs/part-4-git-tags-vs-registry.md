---
title: "Part 4: Consuming Terraform Modules — Git Tags vs Private Registry"
date: 2026-01-01
series_order: 4
series: ["Production-Grade Terraform Patterns"]
tags: ["terraform", "terragrunt", "security", "git", "infrastructure-as-code"]
draft: false
---

This is Part 4 of my series on [Production-Grade Terraform Patterns](/series/production-grade-terraform-patterns/). In [Part 3](/posts/tech-logs/part-3-automating-releases-release-please/), I automated the release of my modules.

Now, I have a Modules Repository with a tag `vpc-v1.1.0`. I have a Live Repository where I want to build that infrastructure. How do I connect them?

There are two primary ways to consume modules:

1. **Git references** — point Terraform at a URL (often with `?ref=` to a tag or commit).
2. **Module registry** — use Terraform’s [module registry protocol](https://developer.hashicorp.com/terraform/internals/module-registry-protocol): the CLI discovers versions and downloads a tarball from a registry (Terraform Cloud/Enterprise, Artifactory, GitLab Terraform Registry, or a custom implementation of that protocol).

That protocol is what makes registry-based installs different from “just git”: list versions, match constraints, then download one version. The link above is the authoritative reference if you want the HTTP shape and behavior.

This is not only a syntax choice; it is a trade-off between simplicity and what the registry gives you (metadata, constraints, UI).

{{< mermaid >}}
flowchart LR
    subgraph Option1 ["Option 1: Git"]
        direction TB
        Live1["Live Repo"] -->|"git::...?ref=tag"| Git["GitHub/GitLab"]
        Git -->|"checkout + subdir"| Live1
    end

    subgraph Option2 ["Option 2: Registry"]
        direction TB
        Live2["Live Repo"] -->|"tfr://... or module source"| Reg["Registry"]
        Reg -->|"tarball (e.g. .tar.gz)"| Live2
    end

    style Option1 fill:#e3f2fd,stroke:#1565c0,stroke-width:2px
    style Option2 fill:#ffebee,stroke:#c62828,stroke-width:2px
{{< /mermaid >}}

## Option 1: Git reference

This is the usual choice for private, internal modules: Terraform pulls source straight from GitHub or GitLab—no registry in the middle.

### Syntax (Terragrunt)

```hcl
terraform {
  # After the repo URL, // is the module root inside the clone (here, modules/vpc).
  source = "git::https://github.com/my-org/infra-modules.git//modules/vpc?ref=vpc-v1.1.0"
}
```

**Pros:** No registry to run; pin with a tag or commit SHA; `//` fits a monorepo layout.

**Cons:** No Terraform-style version constraint on the URL—you pick the ref yourself, so bumps are explicit. Large repos can mean heavier fetches than a single module tarball.

## Option 2: Private registry

If you publish modules to a registry, consumers use a registry address instead of `git::`.

### Syntax (Terragrunt `tfr://`)

```hcl
terraform {
  source = "tfr://app.terraform.io/my-org/vpc/aws?version=1.1.0"
}
```

In plain Terraform (a `module` block in `.tf`), the same logical module is often written with a separate `version` argument. Terraform resolves [version constraints](https://developer.hashicorp.com/terraform/language/block/module#version) (for example `~> 1.0`) against the versions the registry exposes—exactly the flow described in the [module registry protocol](https://developer.hashicorp.com/terraform/internals/module-registry-protocol).

**Pros:** Constraint-aware resolution when you use Terraform’s `module` + `version` pattern; tarball download; many registries expose docs and browsing in a UI.

**Cons:** Operating and publishing to a registry is extra machinery. If you use loose constraints, different applies can resolve to different patch versions unless you also treat upgrades as a deliberate change (same discipline problem as “floating” refs anywhere).

With **Terragrunt**, the practical pattern for `tfr://` is usually an **exact** `?version=` in the URL unless your Terragrunt version and docs say otherwise—do not assume `terragrunt init` applies `~> 1.0` the same way a Terraform `module` block does.

## Verdict for this series

For most internal teams—and for this series—**Git references with an explicit tag or SHA** stay simple, avoid registry operations, and keep “what we deployed” obvious in the live repo.

Using `~> 1.0`-style **implicit** upgrades in production is risky: Tuesday’s apply and Wednesday’s apply can pick different patch releases. Prefer explicit bumps whether you use git or a registry.

## Git authentication (CI/CD)

Do not put tokens in module URLs. Configure Git once in the pipeline so plain `https://github.com/...` sources still work—for example:

```yaml
- name: Configure Git credentials
  run: |
    git config --global url."https://oauth2:${{ secrets.GITHUB_TOKEN }}@github.com".insteadOf https://github.com
```

`GITHUB_TOKEN` only reaches other private repos when your org and repo permissions allow it; otherwise use a PAT or a GitHub App with repository access.

## Summary

1. **Release Please** tags `vpc-v1.1.0`.
2. **Terragrunt** points at that tag via a `git::` source (no credentials in HCL).

Next: who updates those pins across many environments? In **Part 5**, **Renovate** closes that loop.
