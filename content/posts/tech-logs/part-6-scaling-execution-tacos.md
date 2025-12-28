---
title: "Part 6: Scaling Execution — The Case for TACOS (Atlantis, Digger)"
date: 2025-12-20
series_order: 6
series: ["Production-Grade Terraform Patterns"]
tags: ["terraform", "atlantis", "digger", "cicd", "automation", "devops"]
draft: true
---

This is Part 6 of my series on [Production-Grade Terraform Patterns](/series/production-grade-terraform-patterns/). In [Part 5](/posts/tech-logs/part-5-automating-dependency-updates-renovate/), I closed the loop on updates. But one question remains: **When you merge a PR, who actually runs `terraform apply`?**

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

### Stage 3: TACOS (Terraform Automation and Collaboration Software)
This is the modern standard. Tools like **Atlantis**, **Digger**, and **Spacelift** move the execution **into the Pull Request**.

## The Workflow

{{< mermaid >}}
sequenceDiagram
    participant Dev as Developer
    participant Git as GitHub PR
    participant TACOS as Atlantis/Digger
    participant Cloud as AWS

    Dev->>Git: Open Pull Request
    Git->>TACOS: Webhook Event
    TACOS->>TACOS: Plan
    TACOS->>Git: Comment: "Plan: 3 to add"
    
    Dev->>Git: Comment: "atlantis apply"
    Git->>TACOS: Webhook Event
    TACOS->>Cloud: Apply Changes
    TACOS->>Git: Comment: "Apply Successful"
    TACOS->>Git: Merge PR (Optional)
{{< /mermaid >}}

## The Tools: Atlantis vs. Digger

### 1. Atlantis (The Classic)
Atlantis is a Go binary you host yourself (usually on ECS or K8s). It listens to webhooks.
*   **Pros**: Open source standard. Handles locking perfectly (nobody else can apply if you have a lock).
*   **Cons**: It's a "Stateful Pet". You have to maintain a server that faces the public internet (to receive webhooks).

### 2. Digger (The Modern Native)
Digger is "Atlantis for GitHub Actions". It uses your *existing* CI runners.
*   **Pros**: Serverless. No new infrastructure to maintain. Reuses your existing OIDC cloud authentication.
*   **Cons**: Newer ecosystem than Atlantis.

## Why You Need This
If you have more than 3 engineers, locking is essential. TACOS provide:
1.  **State Locking**: Prevents race conditions.
2.  **Plan Review**: The plan output is right there in the PR comment, immutable and searchable.
3.  **Gatekeeping**: You can require "1 approval" before the `apply` command is allowed to run.

## Conclusion

A Complete Platform looks like this:
1.  **Split Repos** (Part 1) isolate failure domains.
2.  **Modules** (Part 2) provide reusable logic.
3.  **Release Please** (Part 3) versions those modules reliably.
4.  **Renovate** (Part 5) keeps dependencies fresh.
5.  **TACOS** (Part 6) ensure safe, audited deployment.

You have now graduated from "running scripts" to building a **Product**.
