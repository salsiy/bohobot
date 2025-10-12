---
title: "Building a Serverless AWS Monitoring System for Less Than a Coffee"
description: "Learn how to build a serverless AWS monitoring system using Steampipe on ECS Fargate with Slack notifications for just $0.04/month."
date: 2025-10-12
categories: ["tech logs"]
tags: ["aws", "steampipe", "terraform", "ecs", "fargate", "monitoring", "slack", "serverless"]
draft: false
---

Last month, I spent four hours tracking down why our AWS bill increased. The culprit? A few forgotten resources across multiple regions that no one remembered creating.

I realized we needed automated infrastructure monitoring, but every solution I looked at cost more than the resources we were trying to optimize. That's when I decided to build something different.

## The monitoring problem

Most AWS monitoring tools are either free but useless, or useful but expensive:

- **Free tools:** CloudWatch alerts exist but won't tell you which S3 buckets are public or which IAM users lack MFA
- **Paid tools:** AWS Config charges $2 per rule. Monitor 50 things? That's $100/month. Datadog? Try $500/month for medium infrastructure

I needed something I could customize without writing boto3 code for every check.

## Discovering Steampipe

Steampipe turns AWS APIs into SQL tables. Instead of this:

```python
import boto3
client = boto3.client('ec2')
response = client.describe_instances()
# ... 20 more lines
```

You write this:

```sql
SELECT instance_id, instance_type
FROM aws_ec2_instance
WHERE instance_state = 'running';
```

Anyone who knows SQL can now write AWS queries.

## System architecture

Here's the complete system I built:

- **EventBridge Schedule** triggers the task daily at 9 AM UTC
- **ECS Fargate Task** runs Steampipe with 256 CPU / 512 MB memory
- **Steampipe Engine** executes SQL queries against AWS APIs (EC2, S3, RDS, IAM)
- **SNS Topic** receives query results and task completion events
- **AWS Chatbot** forwards SNS messages to Slack
- **EventBridge Rule** captures task state changes for completion notifications
- **CloudWatch Logs** stores execution logs for debugging

The system orchestrates scheduled queries, processes results, and delivers real-time notifications—all serverless.

{{< mermaid >}}
graph TB
    EB1[EventBridge Schedule<br/>Daily 9 AM UTC]
    ECS[ECS Fargate Task<br/>256 CPU / 512 MB]
    SP[run_queries.sh]
    STEAM[Steampipe Engine]
    AWS[AWS APIs<br/>EC2, S3, RDS, IAM]
    SNS[SNS Topic<br/>steampipe-reports]
    CB[AWS Chatbot<br/>Amazon Q]
    SLACK[Slack Channel]
    CW[CloudWatch Logs]
    EB2[EventBridge Rule<br/>Task State Change]
    
    EB1 -->|Trigger Daily| ECS
    ECS -->|Execute| SP
    SP -->|Run Queries| STEAM
    STEAM -.Query.-> AWS
    SP -->|Query Results| SNS
    ECS -->|Logs| CW
    ECS -->|Task Stops| EB2
    EB2 -->|Completion Event| SNS
    SNS -->|Forward| CB
    CB -->|Notify| SLACK
    
    style EB1 fill:#ff9900,stroke:#232f3e,stroke-width:2px,color:#fff
    style ECS fill:#ff9900,stroke:#232f3e,stroke-width:2px,color:#fff
    style SP fill:#3b82f6,stroke:#1e40af,stroke-width:2px,color:#fff
    style STEAM fill:#10b981,stroke:#059669,stroke-width:2px,color:#fff
    style AWS fill:#232f3e,stroke:#ff9900,stroke-width:2px,color:#fff
    style SNS fill:#ff4b4b,stroke:#232f3e,stroke-width:2px,color:#fff
    style CB fill:#232f3e,stroke:#ff9900,stroke-width:2px,color:#fff
    style SLACK fill:#611f69,stroke:#4a154b,stroke-width:2px,color:#fff
    style CW fill:#ff9900,stroke:#232f3e,stroke-width:2px,color:#fff
    style EB2 fill:#ff9900,stroke:#232f3e,stroke-width:2px,color:#fff
{{< /mermaid >}}

## How it works

The workflow is straightforward:

1. **EventBridge Schedule** triggers the ECS Fargate task daily
2. **Container starts** and executes the shell script
3. **Steampipe queries** run against AWS APIs, results go to SNS
4. **AWS Chatbot** forwards query results to your Slack channel
5. **Task completes**, EventBridge captures the state change and sends a completion notification

All infrastructure is defined in Terraform with five focused modules: SNS, IAM, networking, ECS, and Slack notifications. Each does one thing well.

The container runs a 90-line shell script:

```bash
for QUERY_FILE in $QUERY_FILES; do
    steampipe query "$QUERY_FILE" --output json > results.json
    aws sns publish --topic-arn "$SNS_TOPIC_ARN" --message "$NOTIFICATION"
done
```

Find SQL files. Run them. Send to SNS. That's it.

Here's what the Slack notifications look like in action:

![Steampipe Slack Notification](/images/posts/steampipe-slack-notification.png)

## Real use cases

To find public RDS instances:

```sql
SELECT db_instance_identifier, engine, region
FROM aws_rds_db_instance
WHERE publicly_accessible = true;
```

To find unused Elastic IPs:

```sql
SELECT public_ip, allocation_id, region
FROM aws_ec2_elastic_ip
WHERE association_id IS NULL;
```

Found four. Saved $144/year.

## Cost breakdown

Here's where it gets interesting:

| Service | Configuration | Monthly Cost |
|---------|--------------|--------------|
| **ECS Fargate** | 0.25 vCPU, 0.5 GB, 5 min/day | $0.03 |
| **CloudWatch Logs** | Standard retention | $0.01 |
| **SNS, EventBridge, ECR, Chatbot** | Standard usage | Free tier |
| **Total** | | **$0.04** |

Four cents a month—that's it.

Four cents. I monitor EC2, S3, RDS, IAM, security groups, and EBS volumes across all regions for less than a penny per day.

## Complete working example

**GitHub Repository:** [https://github.com/salsiy/steampipe-aws-monitor](https://github.com/salsiy/steampipe-aws-monitor)

The complete source code, infrastructure, and deployment guide are available in the repository above. It includes:
- Full Terraform modules (SNS, IAM, networking, ECS, Slack notifications)
- Ready-to-use SQL queries for common AWS checks
- Docker configuration for Steampipe
- EventBridge scheduling setup
- Step-by-step deployment guide

If I left the team tomorrow, someone could understand and modify this in 30 minutes.

## What you could build

This works for any Steampipe plugin - same architecture, different SQL queries. Monitor GitHub repos, Kubernetes clusters, Azure resources, or any of the 140+ available plugins.

## Bottom line

You don't need expensive monitoring tools. You don't need custom Lambda functions for every check. You don't need to maintain boto3 code.

Write SQL. Run it on a schedule. Send results to Slack. Deploy with Terraform.

Total cost: 4 cents per month.

Sometimes the best solutions are the simple ones.

## Frequently asked questions

### What AWS services does this monitoring system use?

The system uses six core AWS services:

- **ECS Fargate** – Runs the containerized Steampipe engine
- **EventBridge** – Schedules daily tasks and captures task completion events
- **SNS** – Receives query results and forwards them to Chatbot
- **AWS Chatbot** – Sends formatted notifications to Slack
- **CloudWatch Logs** – Stores execution logs for debugging
- **ECR** – Hosts the Docker image

### How much does it cost to run this system each month?

Total monthly cost is **$0.04**, broken down as:

- **ECS Fargate:** $0.03 (0.25 vCPU, 0.5 GB RAM, running 5 minutes per day)
- **CloudWatch Logs:** $0.01 (standard log retention)
- **All other services:** Free tier (SNS, EventBridge, ECR, Chatbot)

For comparison, AWS Config would cost $2 per rule, and enterprise monitoring tools like Datadog start at $15 per host.

### Can I monitor multiple AWS regions or accounts?

Yes. Configure Steampipe with multiple AWS connection profiles:

- **Multiple regions:** The AWS plugin queries all regions by default
- **Multiple accounts:** Add assume-role configurations in `steampipe.conf` pointing to cross-account IAM roles
- **Aggregated results:** SQL queries can join data across accounts and regions in a single result set

This makes it ideal for organizations managing dozens of AWS accounts.

### Do I need to write code to add a new check?

No. Adding a check is as simple as creating a `.sql` file in the `queries/` folder:

```sql
-- queries/check-unencrypted-ebs.sql
SELECT volume_id, region
FROM aws_ebs_volume
WHERE encrypted = false;
```

Rebuild the Docker image, push to ECR, and the next scheduled run will include your new check. No Python, no Lambda functions, no CloudFormation updates.

### How do Slack notifications reach my channel?

The notification flow has three steps:

1. **Steampipe → SNS:** Shell script publishes query results to an SNS topic
2. **SNS → AWS Chatbot:** SNS topic triggers the Chatbot subscription
3. **Chatbot → Slack:** Chatbot formats the message and posts it to your configured channel

AWS Chatbot handles authentication via your workspace authorization. You invite `@Amazon Q` to the target channel during setup, and it delivers all future notifications automatically.
