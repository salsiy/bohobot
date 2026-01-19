---
title: "Part 4: Consuming Terraform Modules — Git Tags vs Private Registry"
date: 2026-01-01
series_order: 4
series: ["Production-Grade Terraform Patterns"]
tags: ["terraform", "terragrunt", "security", "git", "infrastructure-as-code"]
draft: true
---

This is Part 4 of my series on [Production-Grade Terraform Patterns](/series/production-grade-terraform-patterns/). In [Part 3](/posts/tech-logs/part-3-automating-releases-release-please/), I automated the release of my modules.

Now, I have a Modules Repository with a tag `vpc-v1.1.0`. I have a Live Repository where I want to build that infrastructure. How do I connect them?

There are two primary ways to consume modules:
1.  **Git References**: Pointing directly to a tag in your Version Control System.
2.  **Registry Protocol**: Using a dedicated artifact server (TFC, Artifactory).

This is not just a syntax choice; it's a trade-off between simplicity and capability.

{{< mermaid >}}
flowchart LR
    subgraph Option1 ["Option 1: Git Tags"]
        direction TB
        Live1["Live Repo"] -->|"git clone ...?ref=vpc-v1.1.0"| Git["GitHub/GitLab"]
        Git -->|"Source Code"| Live1
    end

    subgraph Option2 ["Option 2: Private Registry"]
        direction TB
        Live2["Live Repo"] -->|"request 1.0.x"| Reg["Terraform Cloud / Artifactory"]
        Reg -->|"Download .tar.gz"| Live2
    end
    
    style Option1 fill:#e3f2fd,stroke:#1565c0,stroke-width:2px
    style Option2 fill:#ffebee,stroke:#c62828,stroke-width:2px
{{< /mermaid >}}

## Option 1: The Git Reference (Pragmatic Choice)

This is the standard for most private, internal infrastructure. You bypass intermediate servers and tell Terraform to pull code directly from GitHub or GitLab.

### The Syntax

In your `terragrunt.hcl`:

```hcl
terraform {
  # The double slash // tells Terraform to clone the repo content
  # and then enter the subfolder modules/vpc
  source = "git::https://github.com/my-org/infra-modules.git//modules/vpc?ref=vpc-v1.1.0"
}
```

### The Pros
*   **Zero Infrastructure**: No need for Artifactory or Terraform Cloud.
*   **Immutable Pinning**: You can pin to a tag or a Commit SHA. The code cannot change under your feet.
*   **Monorepo Friendly**: The `//` syntax natively supports our monorepo structure.

### The Cons
*   **No Fuzzy Versioning**: You cannot say `~> 1.0`. You must specify the exact tag. This means upgrades must be explicit.
*   **Fetch Speed**: Cloning large Git repositories can be slower than downloading a zipped artifact.

## Option 2: The Private Registry (Enterprise Choice)

If you use TFC/TFE or GitLab Package Registry, you can publish modules as formal artifacts.

### The Syntax

```hcl
terraform {
  source = "tfr://app.terraform.io/my-org/vpc/aws?version=1.1.0"
}
```

### The Pros
*   **Fuzzy Versioning**: You can use `version = "~> 1.0"`. `terragrunt init` will pick up the latest patch automatically.
*   **Performance**: Downloads are faster (`.tar.gz` vs `git clone`).
*   **Discovery**: Registries usually provide a UI to browse module documentation.

### The Cons
*   **Opacity**: "What version is in prod?" With `~> 1.0`, you have to check state files to know if it's 1.0.1 or 1.0.2.
*   **Complexity**: Requires a build pipeline to package and upload artifacts.

## The Verdict: Stick with Git

For 95% of engineering teams, **Git References are superior**.

Why? Because in Production, "Fuzzy Versioning" is an **anti-pattern**.

If you use `~> 1.0`, and you deploy on Tuesday, you might get `v1.0.1`. If you deploy Wednesday, and someone released `v1.0.2` overnight, you get new code. **Implicit upgrades are dangerous.**

You want explicit actions: "I am upgrading VPC from v1.0.1 to v1.0.2". Git tags force this discipline.

## Handling Authentication

The biggest friction point with Git modules is Authentication. Your Live repo needs to clone your Modules repo.

**Do not embed credentials** in your source URL (`https://user:token@github.com...`).

Instead, use `git config` injection in your CI/CD pipeline:

```yaml
- name: Configure Git Credentials
  run: |
    git config --global url."https://oauth2:${{ secrets.GITHUB_TOKEN }}@github.com".insteadOf https://github.com
```

This tells git: "Whenever you see `https://github.com`, silently inject these credentials." Your Terraform code stays clean, but the pipeline has access.

## Summary

I have established my consumption model:
1.  **Release Please** tags `vpc-v1.1.0`.
2.  **Terragrunt** references that tag via secure Git URL.

But who updates that tag? If I have 50 environments using `v1.0.0`, do I manually edit 50 files?

In **Part 5**, I will deploy **Renovate Bot** to close the loop, automatically detecting releases and updating your live infrastructure.
