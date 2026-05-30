---
title: "Part 6: Scaling Execution — The Case for TACOS"
date: 2026-02-15
series_order: 6
series: ["Production-Grade Terraform Patterns"]
tags: ["terraform", "tacos", "gitops", "cicd", "automation", "devops"]
draft: false
---

This is Part 6 — the final installment — of my series on [Production-Grade Terraform Patterns](/series/production-grade-terraform-patterns/). In [Part 5](/posts/tech-logs/part-5-automating-dependency-updates-renovate/), I closed the loop on updates. But one question remains: **When you merge a PR, who actually runs `terraform apply`?**

In valid "GitOps", humans should never touch the cloud console. And ideally, they shouldn't even run `terraform apply` from their laptops.

## The Evolution of Execution

### Stage 1: Crypto-ClickOps (The Dark Ages)
You run `terraform apply` from your laptop.
*   **Risk**: You have `AdministratorAccess` keys on your disk.
*   **Bug**: You forgot to `git pull` before applying. You just overwrote your colleague's changes.

### Stage 2: Generic CI (Jenkins/GitHub Actions)
You put `terraform apply` in a pipeline that runs on merge to `main`.
*   **Benefit**: Centralized, audited execution.
*   **Friction**: You only see the failure *after* you merge. "Fixing broken main" becomes a daily ritual.

This is where many teams land first — and it works — until PR-time plan review and locking start to matter.

### Stage 3: TACOS (Terraform Automation and Collaboration Software)
This is the modern standard. TACOS tools move plan and apply **into the Pull Request**, so you review infrastructure changes before they touch the cloud.

## The Workflow

{{< mermaid >}}
sequenceDiagram
    participant Dev as Developer
    participant Git as GitHub PR
    participant TACOS as TACOS
    participant Cloud as AWS

    Dev->>Git: Open Pull Request
    Git->>TACOS: Webhook Event
    TACOS->>TACOS: Plan
    TACOS->>Git: Comment: "Plan: 3 to add"
    
    Dev->>Git: Comment: "apply"
    Git->>TACOS: Webhook Event
    TACOS->>Cloud: Apply Changes
    TACOS->>Git: Comment: "Apply Successful"
    TACOS->>Git: Merge PR (Optional)
{{< /mermaid >}}

## TACOS in the wild

The category includes many products. Here are the ones worth knowing — names and official links only:

**PR-native / self-hosted**

*   [Atlantis](https://www.runatlantis.io/) — open-source PR automation server
*   [OpenTaco](https://opentaco.dev/) — successor to [Digger](https://digger.dev/) (Atlantis-style automation on your existing CI runners)
*   [Burrito](https://docs.burrito.tf/latest/) — Kubernetes operator for Terraform PR/MR workflows and drift detection

**Orchestration / platform**

*   [Terramate](https://terramate.io/) — stacks, orchestration, CI/CD integration, and observability

**Managed platforms**

*   [HCP Terraform](https://developer.hashicorp.com/terraform/tutorials/cloud-get-started) (formerly Terraform Cloud) / Terraform Enterprise — HashiCorp's managed offering
*   [Spacelift](https://spacelift.io/) — multi-IaC orchestration platform
*   [Env0](https://www.env0.com/) — cloud governance and IaC automation
*   [Scalr](https://scalr.com/) — Terraform Cloud alternative with PR-native GitOps

[Digger](https://digger.dev/) rebranded to [OpenTaco](https://opentaco.dev/) — same category, new name. If you evaluated Digger in the past, start with OpenTaco.

Pick based on team size, existing CI, and whether you want self-hosted or SaaS. I have not deployed any of these in my reference repos — treat this as a starting point, not a recommendation.

## Why You Need This
If you have more than 3 engineers, locking is essential. TACOS provide:
1.  **State Locking**: Prevents race conditions.
2.  **Plan Review**: The plan output is right there in the PR comment, immutable and searchable.
3.  **Gatekeeping**: You can require "1 approval" before the `apply` command is allowed to run.

## Conclusion

That closes the series. A complete platform looks like this:

1.  **Split Repos** ([Part 1](/posts/tech-logs/part-1-split-repository-pattern/)) isolate failure domains.
2.  **Modules** ([Part 2](/posts/tech-logs/part-2-production-ready-modules/)) provide reusable logic.
3.  **Release Please** ([Part 3](/posts/tech-logs/part-3-automating-releases-release-please/)) versions those modules reliably.
4.  **Git Tags** ([Part 4](/posts/tech-logs/part-4-git-tags-vs-registry/)) wire the live repo to versioned modules.
5.  **Renovate** ([Part 5](/posts/tech-logs/part-5-automating-dependency-updates-renovate/)) keeps dependencies fresh.
6.  **TACOS** (Part 6) automate the final mile — plan and apply in the PR, with locking and review.

You have now graduated from "running scripts" to building a **Product**.
