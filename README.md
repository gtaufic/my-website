# my-website on GCP

A website hosted in Cloud Storage, served through a global external Application Load Balancer with Cloud CDN.

```mermaid
flowchart LR
    visitor["Visitor"] <-->|HTTP| frontend["Global external Application Load Balancer<br/>Cloud CDN enabled"]
    frontend <-->|Fetch content on cache miss| storage["Cloud Storage bucket<br/>Static HTML"]
```

- Terraform manages the cloud resources.
- GitHub Actions deploys using Workload Identity Federation.
   - No service-account keys are needed.

## IaC and Deploy flow

There are two environments: `dev`, based on the `develop` branch, and `production`, based on the `main` branch.

Apply IaC once per environment before its first deployment.

```mermaid
flowchart TB
    develop["develop · dev"] -->|PR: auto plan · Manual: plan / apply| dev_iac["IaC · dev"]
    develop -->|Website push / merge, or manual| dev_deploy["Deploy · dev<br/>Upload → invalidate CDN → verify"]
    develop -->|Merge PR to main| main["main · production"]
    main -->|PR: auto plan · Manual: plan / apply| production_iac["IaC · production"]
    main -->|Website push / merge, or manual| production_deploy["Deploy · production<br/>Upload → invalidate CDN → verify"]

    classDef dev fill:#dbeafe,stroke:#2563eb,color:#1e3a8a
    classDef production fill:#ffedd5,stroke:#ea580c,color:#7c2d12
    class develop,dev_iac,dev_deploy dev
    class main,production_iac,production_deploy production
    linkStyle 0,3 stroke:#16a34a,color:#16a34a,stroke-width:2px
    linkStyle 1,4 stroke:#0891b2,color:#0891b2,stroke-width:2px
    linkStyle 2 stroke:#7c3aed,color:#7c3aed,stroke-width:2px
```

Default region: `us-east1`.

## Repo Structure

```text
my-website/
├── .github/
│   └── workflows/
│       ├── iac.yml                  # PR plans; manual plan and apply
│       └── website.yml              # deploy: website files and CDN invalidation
├── docs/
│   └── images/                      # Step-by-step screenshots
├── iac/
│   ├── .terraform.lock.hcl          # Provider versions and checksums (auto-gen)
│   ├── state.tf                     # Remote state and protected state bucket
│   ├── providers.tf                 # Google and Google Beta providers
│   ├── versions.tf                  # Terraform and provider requirements
│   ├── locals.tf                    # Branches and state-bucket names
│   ├── iam.tf                       # Federation, service accounts, and permissions
│   ├── main.tf                      # Website module configuration (main starting point)
│   ├── variables.tf                 # Project, region, and environment settings
│   ├── outputs.tf                   # Project, authentication, and hosting values
│   ├── environments/
│   │   ├── dev/
│   │   │   ├── state.hcl            # State bucket: my-website-iac-state-dev
│   │   │   └── terraform.tfvars     # Dev environment settings
│   │   └── production/
│   │       ├── state.hcl            # State bucket: my-website-iac-state-production
│   │       └── terraform.tfvars     # Production environment settings
│   └── modules/
│       └── static-website/
│           ├── storage.tf           # Website bucket and public access
│           ├── load-balancer.tf     # Reserved IP, routing, and CDN
│           ├── variables.tf         # Module inputs
│           ├── outputs.tf           # Module outputs
│           └── versions.tf          # Required providers
├── scripts/
│   ├── terraform-init               # Prepare state and GitHub authentication
│   └── deploy-website.sh            # Upload, invalidate cache, and verify release
├── website/
│   ├── assets/
│   ├── index.html
│   └── 404.html
├── .gitignore
└── README.md
```

## Setup

### GCP

In Cloud Shell, run once with an administrative Google account and billing enabled for the project. The script enables APIs, prepares private state buckets for dev and production, and configures GitHub federation and IaC service accounts.

```bash
# For a fork or another repository, use its clone URL and pass its name and numeric IDs below.
git clone https://github.com/gtaufic/my-website.git
cd my-website

# Find your project ID and number
# PROJECT_ID: my-website-xyz123
# NAME: my-website
# PROJECT_NUMBER: 1234567
# ENVIRONMENT:
gcloud projects list

# Find repo id and owner id
# {
#   "repository_id": 1424364185,
#   "owner_id": 67336406
# }
curl -fsSL https://api.github.com/repos/gtaufic/my-website \
  | jq '{repository_id: .id, owner_id: .owner.id}'

# ./scripts/terraform-init "<gcp project id>" "<github owner/repo>" "<repository id>" "<owner id>"
./scripts/terraform-init my-website-xyz123 gtaufic/my-website 1424364185 67336406
```

### GitHub Actions

Add these repository-level Actions secrets, shared by both environments:

**Settings → Secrets and variables → Actions → Secrets → New repository secret**

- `GCP_PROJECT_ID`: GCP project ID.
- `GCP_PROJECT_NUMBER`: Numeric project number.

## First run

After bootstrap, allow up to five minutes for IAM permissions to propagate.

1. Open **Actions → iac → Run workflow**, select `develop` and operation `apply`, and wait for success.
2. Run **deploy** on `develop` to publish the HTML.
3. Once these files are on `main`, repeat **iac → apply**, then **deploy**, on `main` for production.

The first apply imports the bootstrap resources and creates the hosting stack and deployment accounts, including the read-only PR plan account. Later website changes deploy automatically.

**[First apply (production)](https://github.com/gtaufic/my-website/actions/runs/39148919451)**

[![Successful first Terraform apply in production](docs/images/first-apply.png)](https://github.com/gtaufic/my-website/actions/runs/39148919451)

**[First deploy (production)](https://github.com/gtaufic/my-website/actions/runs/39149186580)**

[![First deployment to production in progress](docs/images/first-deploy.png)](https://github.com/gtaufic/my-website/actions/runs/39149186580)

**Deployed version (production)**

![Deployed website version 1.0.1 in production](docs/images/deployed-version.png)

**Page update (v1.0.2)**

Update the page version and replace the GIF, keeping its source credit.

![HTML changes updating the page to version 1.0.2 and replacing the GIF](docs/images/page-update.png)

**Automatic plan (dev)**

Opening or updating a PR targeting `develop` runs a Terraform plan for dev. This website-only update requires no infrastructure changes.

![Successful automatic Terraform plan for dev showing no infrastructure changes](docs/images/auto-plan.png)

For an existing setup, run one manual **iac → apply** with these changes on each environment's branch before using automatic PR plans. This creates the plan account and updates federation.

## Next implementation steps

1. Support custom domains with DNS configuration and managed HTTPS certificates.
2. Deploy versioned web assets to support caching and rollbacks.
