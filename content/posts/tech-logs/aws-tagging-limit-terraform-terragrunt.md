---
title: "Overcoming AWS Tagging Limits in Terraform & Terragrunt"
description: "Learn how to handle the AWS tagging limitation of maximum 10 tags per S3 bucket object when using Terraform and Terragrunt."
date: 2025-05-18
categories: ["tech logs"]
tags: ["terraform", "terragrunt", "aws", "s3", "tagging", "cloud"]
draft: false
---

# Overcoming AWS Tagging Limits in Terraform & Terragrunt

Recently I ran into an annoying AWS limitation while working with Terraform. Turns out S3 objects can only have a maximum of 10 tags, which becomes a problem when you're using provider-level tagging.
The Problem
I like to use default tags at the provider level to make sure all 


provider is defined here 

https://github.com/salsiy/terragrunt-examples/blob/master/root.hcl

```

provider "aws" {
  region = "${local.aws_region}"
  
  default_tags {
    tags = ${jsonencode(local.bucket_tags)}
  }
}
```

Tags for environment is defined here

https://github.com/salsiy/terragrunt-examples/blob/master/dev/env.hcl


```
locals {
  environment      = "dev"
  primary_region   = "us-east-1"
  
  # S3 bucket with MORE than 10 tags (to test limitation)
  bucket_tags = {
    Environment   = "dev"
    Application   = "MyApp"
    Team          = "Engineering"
    CostCenter    = "Development"
    Owner         = "hello@bohobot.com"
    DataClass     = "Internal"
    Backup        = "Daily"
    Monitoring    = "Enabled"
    Compliance    = "Standard"
    Version       = "1.0"
    Purpose       = "Testing"
    CreatedBy     = "Terraform"
  }
  
  object_tags = {
    Environment = "dev"
    Type        = "Config"
    Application = "MyApp"
    Version     = "1.0"
    Owner       = "Engineering"
    # Only 5 tags - well under the 10 tag limit for S3 objects
  }
}
```


This works great for most AWS resources since they support up to 50 tags. But S3 objects? They only support 10 tags maximum. So if I have 8 default tags and want to add a couple more specific tags to my S3 object, I hit the limit and get an error.

The Solution: Multiple Providers

The trick is to create a second AWS provider with fewer default tags, and use that specifically for S3 objects:

```
provider "aws" {
  alias  = "secondary"
  region = "${local.aws_region}"
  
  default_tags {
    tags = ${jsonencode(local.object_tags)}
  }
}
```

Why This Works

Most AWS resources support 50 tags, so the main provider works fine
S3 objects get only the essential tags, staying under the 10-tag limit
You still get consistent tagging across your infrastructure
No need to remember which resources have tag limits


Complete Example
You can find the complete working example in my GitHub repo: 

[terragrunt-examples/modules/s3-bucket-object-tag](https://github.com/salsiy/terragrunt-examples/tree/master)

This simple approach saved me from having to restructure my entire tagging strategy. Sometimes the best solutions are the simplest ones :)