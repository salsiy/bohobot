title: "Part 1: Structuring Terraform at Scale — The Split Repository Pattern"
date: 2025-12-20
series_order: 1
series: ["Production-Grade Terraform Patterns"]
tags: ["terraform", "terragrunt", "infrastructure-as-code", "platform-engineering"]
---

This is Part 1 of our series on [Production-Grade Terraform Patterns](/series/production-grade-terraform-patterns/). We are moving beyond basic tutorials to build a platform capable of handling hundreds of resources, multiple environments, and dozens of engineers.

If you have used Terraform for personal projects, you know how satisfying `terraform apply` can be. You write a `main.tf`, run a command, and infrastructure appears.

But in a production with a growing team, that simplicity disappears.

## The Scaling Problem

As your infrastructure grows, you inevitably hit what I call the "Monolith Wall":

1.  **Blast Radius**: You want to update a security group in Dev, but your state file includes Prod. One mistake destroys the production database.
2.  **State Drift**: You apply changes from your laptop, but your colleague has a different version of the provider, causing conflicts.
3.  **Code Duplication**: Dev, Stage, and Prod are 99% identical. You end up copy-pasting code three times, making maintenance a nightmare.

To solve this, we don't just need better code; we need a better **Architecture**. We need the **Split Repository Pattern** powered by **Terragrunt**.

## The Architecture: Split Repositories

The most vital decision you will make is to separate your **Definition** (Modules) from your **Implementation** (Live State).

Instead of one giant repo, we split our world in two:

### 1. The Modules Repository (The Logic)

This allows us to treat infrastructure code like software libraries.

*   **Content**: Pure Terraform HCL (`.tf` files).
*   **Purpose**: Reusable logic. E.g., "This is how we build a standard EKS cluster."
*   **Key Trait**: It knows nothing about your specific environments. No account IDs, no "prod" strings.
*   **Management**: Strictly versioned using semantic versioning (Tags).

### 2. The Live Repository (The State)

This represents your actual deployable environments.

*   **Content**: Terragrunt configuration (`.hcl` files).
*   **Purpose**: To call the modules and pass in specific inputs.
*   **Key Trait**: If a folder exists here, it exists in the cloud.
*   **Management**: Organized hierarchically by Account, Region, and Environment.

## Why Terragrunt?

You might ask, "Why can't I just use Terraform workspaces or standard `.tfvars` files?"

You can, but Terraform is not designed to be **DRY** (Don't Repeat Yourself) regarding backend configuration.

Without Terragrunt, every component in your live repo needs a hardcoded `backend "s3" {...}` block. If you have 50 components, you have 50 backend configs to maintain. Terragrunt allows you to write this once in a root file and inherit it everywhere.

## The Directory Hierarchy

In your Live repository, the folder structure is your source of truth. We follow the `Account` -> `Region` -> `Environment` hierarchy to physically isolate failure domains.

```text
infrastructure-live/
├── terragrunt.hcl          # 1. Global Configuration (State Bucket, Locking)
├── production-account/     # 2. Account Isolation
│   └── us-east-1/          # 3. Region Isolation
│       └── prod/           # 4. Environment Isolation
│           ├── vpc/        # 5. Component
│           │   └── terragrunt.hcl
│           └── eks-cluster/
│               └── terragrunt.hcl
└── staging-account/
    └── us-east-1/
        └── stage/
            └── vpc/
                └── terragrunt.hcl
```

**Why this works:**

If you run a command inside `production-account/us-east-1/prod/vpc`, Terragrunt can only see that specific folder. It is physically impossible for a command run there to accidentally delete resources in `staging-account`.

## Implementation: How Inheritance Works

The magic of Terragrunt lies in the `include` block.

### 1. The Root Config (`infrastructure-live/terragrunt.hcl`)

This file sits at the top of your repo. It ensures every component stores its state in the correct place automatically.

```hcl
# The Parent Configuration
remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket         = "my-company-terraform-state"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

### 2. The Component Config (`.../prod/vpc/terragrunt.hcl`)

This file lives in the specific environment folder. It does two things:
1.  Inherits the backend config (so you don't type it again).
2.  Points to a specific version of your module.

```hcl
# The Child Configuration

# 1. Inherit settings from root
include "root" {
  path = find_in_parent_folders()
}

# 2. Point to the specific Module Version
terraform {
  source = "git::https://github.com/my-org/infrastructure-modules.git//vpc?ref=v1.0.0"
}

# 3. Pass in Environment-Specific Variables
inputs = {
  cidr_block = "10.0.0.0/16"
  env_name   = "production"
}
```

## Summary

By adopting this structure, we achieve:

1.  **Isolation**: Production and Staging are completely decoupled.
2.  **Clarity**: The file system maps 1:1 to your cloud footprint.
3.  **Efficiency**: Boilerplate is defined once and inherited.

However, we introduced a dependency: `?ref=v1.0.0`.

This string is the most critical part of your stability. If you point to `main`, you break production. In **Part 2**, we will discuss how to build Production-Ready Modules that support this strict versioning strategy.
