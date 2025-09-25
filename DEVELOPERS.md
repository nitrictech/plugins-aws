# Developer Guide

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.5.0
- [Docker](https://www.docker.com/get-started) (for tflint and trivy)

## Usage

```bash
make format    # Format all Terraform files
make test      # Run all tests (format-check, validate, lint, scan)
make clean     # Clean up temp files
```

Tools run in Docker containers - no local installation needed.