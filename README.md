<p align="center">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="docs/logo/suga-dark.svg">
      <source media="(prefers-color-scheme: light)" srcset="docs/logo/suga-light.svg">
      <img width="120" alt="Shows a black logo in light color mode and a white one in dark color mode." src="docs/logo/suga-light.svg">
    </picture>
</p>

<p align="center">
  <a href="https://docs.addsuga.com">Documentation</a> •
  <a href="https://github.com/nitrictech/suga/releases">Releases</a>
</p>

# Suga AWS Infrastructure Plugins

Terraform modules that provide a consistent interface for provisioning AWS cloud resources with best practices built-in.

## Available AWS Plugins

### Storage & CDN
- **S3** - Object storage buckets with configurable access permissions
- **CloudFront** - Global CDN with WAF integration and edge functions

### Compute
- **Lambda** - Serverless functions with container support and VPC integration
- **Fargate** - Container orchestration with ECS and load balancer integration

### Networking
- **VPC** - Virtual private clouds with public/private subnets and NAT gateways
- **Load Balancer** - Application and network load balancers for traffic distribution

### Identity
- **IAM Role** - Identity and access management roles with trust policies

## What These Plugins Do

- Pre-built Terraform modules following AWS Well-Architected Framework
- Automatic IAM role and policy configuration
- Built-in security best practices (WAF rules, security groups, encryption)
- Outputs include ARNs, endpoints, and connection details your application needs
- Optional Go SDK for programmatic resource management

## Getting Started

Each plugin includes:
- `manifest.yaml` - Plugin configuration and input definitions
- `module/` - Terraform module implementation
- `icon.svg` - Visual representation in Suga UI
- Go SDK files for runtime integration (where applicable)

See the [Suga Documentation](https://docs.addsuga.com) for detailed usage instructions.