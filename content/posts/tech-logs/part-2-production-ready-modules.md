```
---
title: "Part 2: Writing Production-Ready Terraform Modules"
date: 2025-12-20
series_order: 2
series: ["Production-Grade Terraform Patterns"]
tags: ["terraform", "modules", "best-practices", "infrastructure-as-code"]
---

This is Part 2 of our series on [Production-Grade Terraform Patterns](/series/production-grade-terraform-patterns/). In [Part 1](/posts/tech-logs/part-1-split-repository-pattern/), we designed the "Split Repository" architecture. Now, we must ensure the core components—the modules—are built correctly.

In a "Hello World" example, a Terraform module is just a folder with some `.tf` files. But in a production environment, a module is a **Software Product**. It has an API (Variables), a Return Value (Outputs), and a Version.

If you write "lazy" modules, your infrastructure will be fragile. Building **Production-Ready Modules** creates a platform that is stable, reusable, and safe.

## The Anatomy of a Module

A production module must be **standardized**. When an engineer opens any module (e.g., `modules/s3-secure`), they should immediately understand the structure. We never dump everything into `main.tf`.

### 1. Standard File Structure

Every module must contain these three files at a minimum:

*   `main.tf`: **The Logic**. Contains the resources (e.g. `aws_s3_bucket`, `aws_instance`). Keep it focused.
*   `variables.tf`: **The Interface**. Defines every input the module accepts. This is your API contract.
*   `outputs.tf`: **The Return Values**. Exposes IDs, ARNs, and endpoints to the consumer.

### 2. Input Validation (The Contract)

The biggest difference between a script and a product is **Validation**.

If a user tries to create a storage bucket with an invalid retention period, the module should fail fast—before it even talks to the cloud API.

Terraform 1.0+ allows us to enforce this contract natively in `variables.tf`:

```hcl
variable "retention_days" {
  type        = number
  description = "Number of days to retain logs. Must be greater than 7."
  default     = 30

  validation {
    condition     = var.retention_days > 7
    error_message = "Retention period must be greater than 7 days to meet compliance standards."
  }
}
```

By adding validation, you shift compliance left. You prevent "garbage in" from ever reaching your cloud provider.

## Managing Dependencies: `versions.tf`

In production, you cannot assume that "Terraform" means the same thing to everyone. Your module might rely on a feature added in Terraform 1.3.

Every module must have a `versions.tf` file that explicitly defines its requirements.

```hcl
terraform {
  # 1. Require a minimum Terraform binary version
  required_version = ">= 1.5.0"

  # 2. Pin Provider Versions
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      # Allow any 5.x version, but do not allow 6.0 (Breaking Changes)
      version = "~> 5.0"
    }
  }
}
```

### The Strategy: Broad Constraints

Notice we used `~> 5.0` (Lazy Constraint) instead of `= 5.12.0` (Exact Pin).

*   **In Live Infrastructure**: We pin **exactly** to ensure reproducibility.
*   **In Modules**: We use **broad constraints**.

We want the module to be compatible with a wide range of provider versions so that consuming teams aren't forced to upgrade their entire stack just to use a minor module update.

## The "Diamond Dependency" Problem

Why are we so obsessed with versioning? Because of dependencies.

Imagine you have a live environment that uses two modules:

1.  Module A (Network) depends on `hashicorp/aws` version 4.0.
2.  Module B (Database) depends on `hashicorp/aws` version 5.0.

If you try to use them together, Terraform will fail to initialize. By maintaining strict versions of your modules (e.g., releasing `v1.0` compatible with AWS v4, and `v2.0` compatible with AWS v5), you allow consumers to upgrade incrementally.

## Static Analysis and Testing

Before releasing a module, we must ensure it is correct. While full integration testing is expensive, static analysis is free and fast.

Your CI pipeline for the module repository should run these two commands on every Pull Request:

1.  `terraform fmt -check`: Ensures code style consistency.
2.  `terraform validate`: Checks for syntax errors and valid references. It catches typos like `var.buket_name` before merge.

## Summary

We have defined what makes a module "Production-Ready":

*   **Standardized**: Predictable file structure.
*   **Safe**: Inputs are validated.
*   **Compatible**: Dependencies are broad but bounded.

But currently, the process is manual. To release `v1.0.0`, humans have to edit files, tag commits, and update changelogs. In **Part 3**, we will implement **Release Please** to automate the versioning process completely.
```
