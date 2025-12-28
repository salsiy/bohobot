---
title: "Part 2: Writing Production-Ready Terraform Modules"
date: 2025-12-20
series_order: 2
series: ["Production-Grade Terraform Patterns"]
tags: ["terraform", "modules", "best-practices", "infrastructure-as-code"]
draft: true
---

This is Part 2 of my series on [Production-Grade Terraform Patterns](/series/production-grade-terraform-patterns/). In [Part 1](/posts/tech-logs/part-1-split-repository-pattern/), I established the architecture for scaling infrastructure. Now, I focus on the building blocks: the **Modules**.

In many tutorials, a Terraform module is treated as a simple folder of `.tf` scripts. However, in a professional engineering environment, a module must be treated as a **Software Product**. It requires a well-defined API (Variables), strict guarantees (Validation), and a stable lifecycle (Versioning).

If you write "lazy" modules, your infrastructure will be fragile. Building **Production-Ready Modules** creates an infrastructure that is stable, reusable, and safe.

## The Anatomy of a Module

{{< mermaid >}}
graph TD
    %% Actors
    User(Consumer)
    Cloud(AWS Provider)

    %% The Module
    subgraph Module ["Terraform Module"]
        direction TB
        Vars("variables.tf<br/>(Inputs)")
        Main("main.tf<br/>(Logic)")
        Outs("outputs.tf<br/>(Outputs)")
        
        Vars --> Main
        Main --> Outs
    end

    %% Data Flow
    User -->|Step 1: Define Inputs| Vars
    Main -->|Step 2: Create Resources| Cloud
    Outs -->|Step 3: Return Attributes| User

    %% Styling
    style Module fill:#f4f6f7,stroke:#bdc3c7,stroke-width:2px,rx:10,ry:10
    
    style Vars fill:#fff,stroke:#e67e22,stroke-width:2px,rx:5,ry:5
    style Main fill:#fff,stroke:#3498db,stroke-width:2px,rx:5,ry:5
    style Outs fill:#fff,stroke:#9b59b6,stroke-width:2px,rx:5,ry:5

    style User fill:#34495e,color:#fff,stroke-width:0px,rx:5,ry:5
    style Cloud fill:#34495e,color:#fff,stroke-width:0px,rx:5,ry:5
{{< /mermaid >}}

A production module must be **standardized**. When an engineer opens any module (e.g., `modules/s3-secure`), they should immediately understand the structure. I never dump everything into `main.tf`.

For a comprehensive set of rules on naming and organization, I recommend the official [HashiCorp Terraform Style Guide](https://developer.hashicorp.com/terraform/language/style).

### 1. Standard File Structure

Every module must contain these three files at a minimum:

*   `main.tf`: **The Logic**. Contains the resources (e.g. `aws_s3_bucket`, `aws_instance`). Keep it focused.
*   `variables.tf`: **The Interface**. Defines every input the module accepts. This is your API contract.
*   `outputs.tf`: **The Return Values**. Exposes IDs, ARNs, and endpoints to the consumer.

### 2. Input Validation (The Contract)

The biggest difference between a script and a product is **Validation**.

If a user tries to create a storage bucket with an invalid retention period, the module should fail fast—before it even talks to the cloud API.

Terraform 1.0+ allows me to enforce this contract natively in `variables.tf`:

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

Notice I used `~> 5.0` (Lazy Constraint) instead of `= 5.12.0` (Exact Pin).

*   **In Live Infrastructure**: I pin **exactly** to ensure reproducibility.
*   **In Modules**: I use **broad constraints**.

I want the module to be compatible with a wide range of provider versions so that consuming teams aren't forced to upgrade their entire stack just to use a minor module update.

## The "Diamond Dependency" Problem

Why am I so obsessed with versioning? Because of dependencies.

Imagine you have a live environment that uses two modules:

1.  Module A (Network) depends on `hashicorp/aws` version 4.0.
2.  Module B (Database) depends on `hashicorp/aws` version 5.0.

If you try to use them together, Terraform will fail to initialize. By maintaining strict versions of your modules (e.g., releasing `v1.0` compatible with AWS v4, and `v2.0` compatible with AWS v5), you allow consumers to upgrade incrementally.

## Static Analysis and Testing

Before releasing a module, I must ensure it is correct. While full integration testing is expensive, static analysis is free and fast.

Your CI pipeline for the module repository should run these two commands on every Pull Request:

1.  `terraform fmt -check`: Ensures code style consistency.
2.  `terraform validate`: Checks for syntax errors and valid references.

However, built-in tools aren't enough. I highly recommend adding these two advanced scanners:

### 3. [TFLint](https://github.com/terraform-linters/tflint) (Quality Assurance)

`terraform validate` only checks syntax. `tflint` checks for **semantics** and provider-specific issues. It acts like a spell-checker for your cloud resources.

For example, `terraform validate` thinks `instance_type = "t9.large"` is fine (it's a valid string). **TFLint** knows that `t9.large` doesn't exist in AWS and will warn you immediately.

It is also excellent at detecting **unused declarations**. If you define a `variable "foo"` but never use it, TFLint will flag it, keeping your codebase clean.

To enable this, add a `.tflint.hcl` to your repository root:

```hcl
plugin "aws" {
    enabled = true
    version = "0.32.0"
    source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

plugin "terraform" {
    enabled = true
    preset  = "recommended"
}
```

```bash
tflint --init
tflint
```

### 4. [Checkov](https://github.com/bridgecrewio/checkov) (Security Compliance)

Infrastructure as Code allows you to build insecure things very quickly. **Checkov** is a static code analysis tool for infrastructure that scans for security misconfigurations.

It has hundreds of built-in policies. If you try to create an unencrypted S3 bucket or a security group open to `0.0.0.0/0`, Checkov will fail the build.

```bash
checkov -d .
```

By adding these to your CI pipeline, you ensure that **Quality** and **Security** are baked into every module version.

## Summary

I have defined what makes a module "Production-Ready":

*   **Standardized**: Predictable file structure.
*   **Safe**: Inputs are validated.
*   **Compatible**: Dependencies are broad but bounded.

But currently, the process is manual. To release `v1.0.0`, humans have to edit files, tag commits, and update changelogs. In **Part 3**, I will implement **Release Please** to automate the versioning process completely.
```
