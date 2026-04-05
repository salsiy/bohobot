---
title: "Part 4: Consuming Terraform Modules: Git Tags vs Private Registry"
date: 2026-01-01
series_order: 4
series: ["Production-Grade Terraform Patterns"]
tags: ["terraform", "terragrunt", "security", "git", "infrastructure-as-code"]
draft: false
---

This is Part 4 of my series on [Production-Grade Terraform Patterns](/series/production-grade-terraform-patterns/). In [Part 3](/posts/tech-logs/part-3-automating-releases-release-please/), I automated tagging and releases for my modules. Now I need to **consume** those modules from a separate live repository.

> **Prerequisite**: This guide assumes you are using the **split repo layout** from [Part 1](/posts/tech-logs/part-1-split-repository-pattern/) and that modules are versioned as in [Part 2](/posts/tech-logs/part-2-production-ready-modules/) and [Part 3](/posts/tech-logs/part-3-automating-releases-release-please/).

Suppose the modules repo has a tag `vpc-v1.1.0` and the live repo should deploy that infrastructure. There are two primary ways to wire that up:

1. **Git references**: Point Terraform at a URL (usually with `?ref=` set to a tag or commit).
2. **Module registry**: Use Terraform's [module registry protocol](https://developer.hashicorp.com/terraform/internals/module-registry-protocol). The CLI lists versions, matches constraints, downloads a tarball from a registry (Terraform Cloud/Enterprise, Artifactory, GitLab Terraform Registry, or any implementation of that protocol).

That protocol is what makes registry installs different from plain Git: you get version metadata and a standard download path. The HashiCorp doc above is the place to read if you care about the HTTP details.

This is not only a syntax choice. It is a trade-off between keeping things simple and paying the cost of running a registry (metadata, semver constraints, a UI).

{{< ltr >}}
{{< mermaid >}}
%%{init: {"themeVariables": {"fontSize": "24px", "fontFamily": "system-ui, Segoe UI, sans-serif", "primaryTextColor": "#111", "primaryBorderColor": "#444"}, "flowchart": {"nodeSpacing": 88, "rankSpacing": 96, "padding": 40, "curve": "basis", "htmlLabels": true}}}%%
%% Option 1 left, Option 2 right (LR; ltr shortcode avoids RTL mirror)
flowchart LR
    subgraph Opt1 ["① Option 1: Git reference"]
        direction TB
        L1["Live repo<br/>Terragrunt / Terraform"]
        VCS["Git host<br/>modules monorepo"]
        L1 <-->|"git:: + ?ref + subfolder"| VCS
    end

    subgraph Opt2 ["② Option 2: Module registry"]
        direction TB
        L2["Live repo<br/>Terragrunt / Terraform"]
        REG["Registry<br/>TFC · Artifactory · …"]
        L2 <-->|"tfr or module block + version → tarball"| REG
    end

    style Opt1 fill:#e8f4fc,stroke:#1565c0,stroke-width:3px
    style Opt2 fill:#fce8e6,stroke:#b71c1c,stroke-width:3px
    style L1 fill:#fff,stroke:#1565c0,stroke-width:2px
    style VCS fill:#fff,stroke:#1565c0,stroke-width:2px
    style L2 fill:#fff,stroke:#b71c1c,stroke-width:2px
    style REG fill:#fff,stroke:#b71c1c,stroke-width:2px
{{< /mermaid >}}
{{< /ltr >}}

## Option 1: Git reference

For private, internal modules this is usually what I reach for first. Terraform pulls source straight from GitHub or GitLab. There is no registry in the middle.

### Syntax (Terragrunt)

```hcl
terraform {
  # After the repo URL, // is the module root inside the clone (here, modules/vpc).
  source = "git::https://github.com/my-org/infra-modules.git//modules/vpc?ref=vpc-v1.1.0"
}
```

**Pros:** No registry to run; pin with a tag or commit SHA; the `//` path fits a monorepo layout.

**Cons:** You cannot put a Terraform-style semver constraint on the Git URL itself. You choose the ref, so every bump is explicit. Very large repos can mean heavier fetches than downloading a single module tarball.

## Option 2: Private registry

If you publish modules to a registry, consumers use a registry address instead of `git::`.

### Syntax (Terragrunt `tfr://`)

```hcl
terraform {
  source = "tfr://app.terraform.io/my-org/vpc/aws?version=1.1.0"
}
```

In plain Terraform (a `module` block in `.tf`), the same module is often declared with a separate `version` argument. Terraform resolves [version constraints](https://developer.hashicorp.com/terraform/language/block/module#version) (for example `~> 1.0`) against the versions the registry publishes. That resolution flow is what the [module registry protocol](https://developer.hashicorp.com/terraform/internals/module-registry-protocol) describes.

**Pros:** When you use Terraform's `module` plus `version` pattern, you get constraint-aware resolution; downloads are typically tarballs; many registries expose docs and search in a UI.

**Cons:** You need a pipeline (or process) to publish versions. If you use loose constraints, one apply on Tuesday and another on Wednesday can resolve to different patch versions unless you treat upgrades as an explicit change. That is the same discipline problem as floating refs anywhere.

With **Terragrunt**, the practical approach for `tfr://` is usually an **exact** `?version=` in the URL unless your Terragrunt version and docs say otherwise. Do not assume `terragrunt init` resolves `~> 1.0` the same way a Terraform `module` block does.

## What I use in this series

For most internal teams, and for this walkthrough, **Git references with an explicit tag or SHA** stay simple, skip extra infrastructure, and keep what we deployed obvious in the live repo.

Using `~> 1.0`-style **implicit** upgrades in production is risky: two applies on different days can pick different patch releases without anyone editing config. I prefer explicit bumps, whether the source is Git or a registry.

## Git authentication (CI/CD)

Do not embed tokens in module URLs. Configure Git once in the pipeline so plain `https://github.com/...` sources still work. For example:

```yaml
- name: Configure Git credentials
  run: |
    git config --global url."https://oauth2:${{ secrets.GITHUB_TOKEN }}@github.com".insteadOf https://github.com
```

`GITHUB_TOKEN` only reaches other private repos when your org and workflow permissions allow it. Otherwise use a PAT or a GitHub App with repository access.

## Summary

1. **Release Please** tags `vpc-v1.1.0`.
2. **Terragrunt** points at that tag with a `git::` source (no credentials in HCL).

In [Part 5](/posts/tech-logs/part-5-automating-dependency-updates-renovate/), I use **Renovate** so those pins update across many environments without hand-editing every file.
