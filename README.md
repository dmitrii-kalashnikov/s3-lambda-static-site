# s3-lambda-static-site

# Terraform Static Website Deployment

This repository contains Terraform configuration files to deploy a static website using an S3 bucket and a Lambda function. The Lambda function updates the bucket policy to allow Cloudflare IPs.

## Prerequisites

- Terraform `~> 1.8.4`
- AWS CLI configured with your profile

## Getting Started

### Clone the Repository

```sh
git clone https://github.com/your-repo/terraform-static-website.git
cd terraform-static-website

### Initialize Terraform
terraform init

### Plan the Deployment
terraform plan

### Apply the Deployment
terraform apply

### Destroy the Deployment
terraform destroy

