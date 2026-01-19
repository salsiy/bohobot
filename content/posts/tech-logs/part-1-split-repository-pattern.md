---
title: "Part 1: Structuring Terraform at Scale — The Split Repository Pattern"
date: 2025-12-20
series_order: 1
series: ["Production-Grade Terraform Patterns"]
tags: ["terraform", "terragrunt", "infrastructure-as-code"]
draft: false
---


<br>

{{< mermaid >}}
graph TD
    %% REPOS
    LiveRepo(terraform-patterns-live)
    ModRepo(terraform-patterns-modules)

    %% MODULE VERSIONS
    ModV1("ecs-cluster-v0.1.0<br/>(Stable)")
    ModV2("ecs-cluster-v0.2.0<br/>(Beta)")
    
    ModRepo --- ModV1
    ModRepo --- ModV2

    %% LIVE BRANCH 1: PRODUCTION
    LiveRepo --> ProdAcc[Account: production-account] --> ProdReg[Region: us-east-1] --> ProdApp[ecs-cluster]
    
    %% LIVE BRANCH 2: STAGING
    LiveRepo --> StageAcc[Account: staging-account] --> StageReg[Region: us-east-1] --> StageApp[ecs-cluster]

    %% LIVE BRANCH 3: DEV
    LiveRepo --> DevAcc[Account: development-account] --> DevReg[Region: us-east-1] --> DevApp[ecs-cluster]

    %% VERSION BINDINGS
    ProdApp -.->|binds to| ModV1
    StageApp -.->|binds to| ModV2
    DevApp -.->|binds to| ModV2

    %% STYLING
    style LiveRepo fill:#34495e,color:#fff,stroke-width:0px,rx:5,ry:5
    style ModRepo fill:#34495e,color:#fff,stroke-width:0px,rx:5,ry:5
    style ModV1 fill:#fff,stroke:#34495e,stroke-width:2px,rx:5,ry:5
    style ModV2 fill:#fff,stroke:#34495e,stroke-width:2px,rx:5,ry:5

    style ProdAcc fill:#e8f8f5,stroke:#1abc9c,color:#000,rx:5,ry:5
    style ProdReg fill:#a2d9ce,stroke:#16a085,color:#000,rx:5,ry:5
    style ProdApp fill:#fff,stroke:#1abc9c,stroke-width:2px,rx:5,ry:5

    style StageAcc fill:#fef9e7,stroke:#f1c40f,color:#000,rx:5,ry:5
    style StageReg fill:#f9e79f,stroke:#f39c12,color:#000,rx:5,ry:5
    style StageApp fill:#fff,stroke:#f1c40f,stroke-width:2px,rx:5,ry:5

    style DevAcc fill:#f4ecf7,stroke:#9b59b6,color:#000,rx:5,ry:5
    style DevReg fill:#e8daef,stroke:#8e44ad,color:#000,rx:5,ry:5
    style DevApp fill:#fff,stroke:#9b59b6,stroke-width:2px,rx:5,ry:5
{{< /mermaid >}}

<br>

This is Part 1 of my series on [Production-Grade Terraform Patterns](/series/production-grade-terraform-patterns/). I am moving beyond basic tutorials to build an infrastructure capable of handling hundreds of resources, multiple environments, and dozens of engineers.

This approach is heavily inspired by the reference architectures provided by Gruntwork. Specifically, it adapts the patterns demonstrated in their [Infrastructure Catalog](https://github.com/gruntwork-io/terragrunt-infrastructure-catalog-example) and [Live Stacks](https://github.com/gruntwork-io/terragrunt-infrastructure-live-stacks-example) examples.

**Source Code:**
*   Modules: https://github.com/salsiy/terraform-patterns-modules
*   Live: https://github.com/salsiy/terraform-patterns-live

Before we start, I assume you have some basic familiarity with Terraform and Terragrunt. If you are just getting started, I highly recommend checking out the official [HashiCorp Terraform Tutorials](https://developer.hashicorp.com/terraform/tutorials) and the [Terragrunt Quick Start Guide](https://terragrunt.gruntwork.io/docs/getting-started/quick-start/). Also, for the purpose of this demonstration, I will be using **AWS Cloud**.

If you have used Terraform for personal projects, you know how satisfying `terraform apply` can be. You write a `main.tf`, run a command, and infrastructure appears.

But in a production with a growing team, that simplicity disappears.

## The Scaling Problem

As your infrastructure scales, you will inevitably face the pitfalls of a monolithic architecture:

**Blast Radius**: You want to update a security group in Dev, but your state file includes Prod. One mistake destroys the production database. With Terragrunt, each unit (module) will have a separate state file, strictly isolating the impact of any change.

**Environment Drift**: You apply a fix in Dev, but forget to apply it to Prod. Over time, your environments diverge, and deployments become a guessing game. This setup solves this by packing infrastructure as **Versioned Modules**, ensuring the exact same code is promoted from environment to environment.

**Code Duplication**: Dev, Stage, and Prod are 99% identical. You end up copy-pasting code three times, making maintenance a nightmare.

To solve this, you don't just need better code; you need a better **Architecture**. I recommend the **Split Repository Pattern** powered by **Terragrunt**.




## The Development Workflow: Scaled Trunk-Based

Architecture is useless without a workflow. To manage these repositories effectively, I adopt **[Scaled Trunk-Based Development](https://trunkbaseddevelopment.com/)**.

In Infrastructure as Code, long-lived feature branches are dangerous. If you branch off for 2 weeks to build a VPC, and I branch off to build ECS, whoever merges last faces a massive, risky conflict resolution that could break production.

**The Rules:**
1.  **Short-Lived Branches**: Features are merged to `main` within hours, not days.
2.  **Main is Production**: The `main` branch of the *Live Repo* should always reflect what is currently deployed (or being deployed).


This aligns perfectly with the Split-Repo pattern: you iterate rapidly on Modules (Logic) using releases, while your Live Repo (State) moves forward in small, incremental steps.

## The Architecture: Split Repositories

The most vital decision you will make is to separate your **Definition** (Modules) from your **Implementation** (Live State).

Instead of one giant repo, I split my world in two:

### 1. [The Modules Repository (The Logic)](https://github.com/salsiy/terraform-patterns-modules)

This allows us to treat infrastructure code like software libraries.

*   **Content**: Pure Terraform HCL (`.tf` files).
*   **Purpose**: Reusable logic. E.g., "This is how I build a standard ECS cluster."
*   **Key Trait**: It knows nothing about your specific environments. No account IDs, no "prod" strings.
*   **Management**: Strictly versioned using semantic versioning (Tags).

### 2. [The Live Repository (The State)](https://github.com/salsiy/terraform-patterns-live)

This represents your actual deployable environments.

*   **Content**: Terragrunt configuration (`.hcl` files).
*   **Purpose**: To call the modules and pass in specific inputs.
*   **Key Trait**: If a folder exists here, it exists in the cloud.
*   **Management**: Organized hierarchically by Account, Region, and Environment.

## Why Terragrunt?

Terragrunt is a thin wrapper that significantly enhances Terraform without replacing it. Its primary goal is to **keep your configuration DRY (Don't Repeat Yourself)**. By automating remote state setup and enforcing consistency, it eliminates code duplication across your Dev, Stage, and Prod environments, making complex infrastructure maintainable and scalable.

You might ask, "Why can't I just use Terraform workspaces or standard `.tfvars` files?"

You can, but Terraform is not designed to be **DRY** regarding backend configuration.

Without Terragrunt, every component in your live repo needs a hardcoded `backend "s3" {...}` block. If you have 50 components, you have 50 backend configs to maintain. Terragrunt allows you to write this once in a root file and inherit it everywhere.

## The Directory Hierarchy

In your Live repository, the folder structure is your source of truth. I follow the `Account` -> `Region` -> `Environment` hierarchy to physically isolate failure domains.


```text
terraform-patterns-modules/     # 1. The Logic
├── ecs-cluster/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── vpc/
└── ...

terraform-patterns-live/        # 2. The State
├── root.hcl                # 1. Global Configuration (State Bucket, Locking)
├── tags.yaml               # 2. Global Tags
├── _envcommon/             # 3. DRY Module Configs (Global)
│   ├── vpc.hcl
│   └── ecs-cluster.hcl
├── production-account/     # 4. Account Isolation
│   └── us-east-1/          # 5. Region Isolation
│       ├── vpc/            # 6. Component
│       │   └── terragrunt.hcl
│       └── ecs-cluster/
│           └── terragrunt.hcl
├── development-account/
│   └── us-east-1/
│       └── ...
└── staging-account/
    └── ...
```

<br>



**Why this works:**

If you run a command inside `production-account/us-east-1/prod/vpc`, Terragrunt can only see that specific folder. It is physically impossible for a command run there to accidentally delete resources in `staging-account`.

## Implementation: How Inheritance Works

The magic of Terragrunt lies in the `include` block.

### 1. The Root Config (`terraform-patterns-live/root.hcl`)

This file sits at the top of your repo. It ensures every component stores its state in the correct place automatically.

```hcl
locals {
  # Automatically load account & region variables
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  account_name = local.account_vars.locals.account_name
  aws_region   = local.region_vars.locals.aws_region
}

# Generate an AWS provider block
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${local.aws_region}"
  # ...
}
EOF
}

# Configure Terragrunt to automatically store tfstate files in an S3 bucket
remote_state {
  backend = "s3"
  config = {
    encrypt        = true
    bucket         = "terragrunt-example-tf-state-${local.account_name}-${local.aws_region}"
    key            = "${path_relative_to_include()}/tf.tfstate"
    # ...
  }
}

# Pass these to all child modules
inputs = merge(
  local.account_vars.locals,
  local.region_vars.locals,
)
```

### 2. The DRY Config (`_envcommon/ecs-cluster.hcl`)

This is where the magic happens. We define the module `source` and common variables once. All environments (Dev, Stage, Prod) inherit from here.

```hcl
  source = "git::https://github.com/my-org/terraform-patterns-modules.git//ecs-cluster?ref=ecs-cluster-v0.1.0"
}

inputs = {
  # Common inputs for ALL environments
  cluster_name = "main-cluster"
}
```

### 3. The Component Config (`.../us-east-1/ecs-cluster/terragrunt.hcl`)

This file lives in the specific environment folder. It does two things:
1.  Inherits the backend config (so you don't type it again).
2.  Points to a specific version of your module.

```hcl
# The Child Configuration
include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/ecs-cluster.hcl"
}

inputs = {
  env_name = "production"

  services = {
    app-service = {
      cpu    = 256
      memory = 512
      # ... container definitions ...
    }
  }
}
```

### 4. Global Tagging: Consistent Metadata

In the root of the repo, you'll notice a `tags.yaml`. This file defines tags that **every single resource** in your infrastructure must have (e.g., `Project`, `Owner`, `ManagedBy`).

```yaml
# tags.yaml
Project: "terraform-patterns"
Owner: "DevOps Team"
ManagedBy: "Terraform/Terragrunt"
```

In `root.hcl`, we read this file and inject it into every module. This guarantees that whether you deploy a database in Prod or a load balancer in Dev, they all carry consistent metadata for billing and auditing.

## Conclusion

Transitioning to the Split Repository Pattern is the difference between maintaining a hobby project and operating a professional infrastructure platform.

*   **Zero Ambiguity**: The file structure tells you exactly what is deployed where.
*   **Zero Drift**: Versioned modules ensure that Staging and Production run the exact same logic.
*   **Total Confidence**: Physical isolation means you can break Dev without ever risking Prod.

In [Part 2: Production-Ready Modules](/series/production-grade-terraform-patterns/part-2-production-ready-modules/), we will dive deep into the **Modules Repository** and learn how to write clean, reusable, and versioned Terraform code.
