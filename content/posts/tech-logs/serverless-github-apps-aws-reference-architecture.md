---
title: "Serverless GitHub Apps on AWS: A Reference Architecture"
description: "How to run a GitHub App on AWS Lambda with Function URLs, webhook verification, and SSM-backed credentials."
date: 2026-05-31
categories: ["tech logs"]
tags: ["github", "github-apps", "aws", "lambda", "serverless", "webhooks", "go", "github-actions", "devops"]
draft: false
---

This post explains a reference setup for running a [GitHub App](https://docs.github.com/en/apps) on AWS Lambda. It is not tied to one use case. The idea is a pattern you can copy: take signed webhooks, prove they came from GitHub, call the API as the app, and return the right HTTP status when GitHub sends the same event again.

The code is here: [github.com/salsiy/serverless-github-app](https://github.com/salsiy/serverless-github-app). It has Terraform for Lambda and a Go handler you can swap out while keeping the rest.

## Go libraries

The handler is plain Go (1.24). These are the main dependencies:

| Library | What it does here |
|---------|-------------------|
| [aws-lambda-go](https://github.com/aws/aws-lambda-go) | Lambda handler and Function URL request type |
| [aws-sdk-go-v2](https://github.com/aws/aws-sdk-go-v2) (SSM) | Read app ID, key, and webhook secret from Parameter Store |
| [ghinstallation](https://github.com/bradleyfalzon/ghinstallation) | GitHub App auth and installation access tokens |
| [go-github](https://github.com/google/go-github) | GitHub REST API (GetContents for config, Dispatch for fan-out) |
| [viper](https://github.com/spf13/viper) | Parse `.github/app-config.yaml` in the sample |
| [zap](https://github.com/uber-go/zap) | Structured logs to CloudWatch |

Webhook HMAC uses the Go standard library (`crypto/hmac`, `crypto/sha256`). There is no extra signing package.

## How the pieces fit

A GitHub App is its own app on GitHub. It has keys, permissions, and webhooks. When something happens in an org or repo, GitHub POSTs JSON to your URL and signs it with a secret. Your code checks the signature, reads `installation` from the payload, gets a short-lived token, and uses that token for API calls for that install only.

In this repo the URL is a **Lambda Function URL** with `authorization_type = "NONE"`. There is no API Gateway and no server that runs all the time. On startup, `init()` loads the app ID, private key, and webhook secret from **SSM**. Environment variables hold SSM paths, not the secrets themselves. The middle of the handler is sample code. In a fork you usually keep verify, auth, secrets, and status codes. You replace the business logic.

{{< mermaid >}}
flowchart TB
    subgraph github [GitHub]
        App[GitHub App]
        Webhook[Webhook POST]
        ContentsAPI[Contents API]
        DispatchAPI[repository_dispatch]
    end
    subgraph aws [AWS]
        FuncURL[Lambda Function URL]
        Lambda[Go bootstrap]
        SSM[SSM Parameter Store]
        CW[CloudWatch Logs]
    end
    App --> Webhook
    Webhook -->|HTTPS| FuncURL
    FuncURL --> Lambda
    Lambda -->|init| SSM
    Lambda -->|HMAC verify| Lambda
    Lambda -->|read app-config.yaml| ContentsAPI
    Lambda -->|fan-out| DispatchAPI
    Lambda --> CW
{{< /mermaid >}}

## One webhook, step by step

{{< mermaid >}}
sequenceDiagram
    participant GH as GitHub
    participant URL as LambdaFunctionURL
    participant L as GoHandler
    participant SSM as SSM
    participant API as GitHubAPI

    Note over L,SSM: init on warm container
    L->>SSM: app-id, private key, webhook secret

    GH->>URL: POST body + x-hub-signature-256
    URL->>L: LambdaFunctionURLRequest
    L->>L: HMAC-SHA256 over raw body
    alt unsupported event
        L-->>GH: 200
    else supported
        L->>API: GetContents .github/app-config.yaml
        loop each target
            L->>API: repository_dispatch
        end
        L-->>GH: 200 or 500
    end
{{< /mermaid >}}

GitHub signs the **raw body**. The handler checks `x-hub-signature-256` before it parses JSON. Lambda Function URLs turn header names lowercase. The code must read `x-hub-signature-256`, not `X-Hub-Signature-256`. That is why verification often works on your laptop but fails in Lambda.

The header looks like `sha256=` plus hex. The code strips `sha256=`, hashes the body with the webhook secret, and compares with `hmac.Equal`. No header returns **400**. Bad signature returns **401**. Bad JSON returns **400**. Events the handler does not support return **200** so GitHub does not retry. Errors in `processWebhook` (like missing config) return **500** and GitHub will try again.

For API calls, `ghinstallation` wraps the HTTP transport and `go-github` is the client. Together they use the app ID, installation ID from the payload, and PEM from SSM. The sample uses that client to read `.github/app-config.yaml` and call the REST API. Change those calls. Keep the client setup.

## Status codes

| What happened | HTTP | GitHub |
|---------------|------|--------|
| Event not supported | 200 | No retry |
| Bad signature or body | 400 / 401 | No retry |
| Handler failed | 500 | Retries |

In the sample, if one `repository_dispatch` fails, the code logs it and moves on. The webhook can still return **200**. That way one bad repo does not make GitHub resend the whole event. Change this if you need all targets to succeed.

## Deploy

Terraform deploys Go on `provided.al2023` (**arm64**), 256 MB, 30 second timeout, plus a Function URL. IAM can only read three SSM parameters. No VPC. Example parameters:

```bash
aws ssm put-parameter --name "/dev/github-app/app-id" --value "YOUR_APP_ID" --type "String"
aws ssm put-parameter --name "/dev/github-app-private-key" --value file://app.private-key.pem --type SecureString
aws ssm put-parameter --name "/dev/github-app-webhook-secret" --value "YOUR_SECRET" --type SecureString
```

Run `make deploy`. Set the GitHub App webhook URL to the Function URL output. Use the same webhook secret in GitHub and in SSM.

## What to change in the repo

| File | Role |
|------|------|
| `app/webhook.go` | Keep. Signature check. |
| `app/main.go` | Keep. Entry point, `init()`, status codes. |
| `app/github_auth.go` | Keep. GitHub client per installation. |
| `app/config.go` | Keep. SSM reads. |
| `app/webhook_processor.go` | Replace. Event routing (sample uses `release`). |
| `app/repo_config_loader.go`, `app/github_dispatch.go` | Replace. Sample config and API calls. |

The sample only runs when the payload has a `release` object. It reads `.github/app-config.yaml` as an example. You do not have to use that file. Run `make test` for checks. Use `terraform output` for the function name when tailing logs.

## Wrap-up

A GitHub App on Lambda is mostly the same chores every time. Trust the webhook. Load secrets from SSM. Stay within the installation. Return status codes GitHub understands. This repo does that work once so you can focus on the logic in the middle. Fork it, replace the middle, keep the rest.
