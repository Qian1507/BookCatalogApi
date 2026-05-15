# Deployment Guide

## Deployment Architecture

The deployment provisions and configures the following Azure resources and services:

- Azure App Service Plan (Linux B1)
- Azure Web App (.NET 10)
- Azure SQL Server
- Azure SQL Database (Serverless)
- Azure Key Vault
- Azure Managed Identity
- Azure Application Insights
- Azure Storage Account
- Blob Storage Containers
- Web App Logging
- Web App Access Restrictions
- SQL Firewall Rules
---

## 1. Clone Repository

```bash
git clone <repository-url>
cd BookCatalogApi
```

---

## 2. Install Prerequisites

Install the following tools before deployment:

- Azure CLI
- .NET 10 SDK
- Git

Verify installation:

```bash
az --version
dotnet --version
git --version
```

---

## 3. Configure Local Environment

Copy the example environment file:

```cmd
copy .env.example .env
```

The deployment script supports both .env and .env.local.

Priority order:

1. .env.local
2. .env

If .env.local exists, it overrides .env.

This makes it possible to keep machine-specific configuration outside the shared .env file

## 3.1 Configure Environment Variables

Update the environment file with your own Azure resource names and credentials:

```env
RG=
LOCATION=

PLAN_NAME=
APP_NAME=

SQL_SERVER_NAME=
DB_NAME=
SQL_ADMIN_USER=
SQL_ADMIN_PASSWORD=

KV_NAME=
STORAGE_NAME=
```

The `.env` file is used only for local deployment scripts and should never be committed to source control. 

## 3.2 Security and Git Ignore Rules

The following files must NOT be committed to Git:

```text
.env
.env.local
publishProfile.xml
*.pubxml
*.publishsettings
```

Recommended `.gitignore` configuration:

```gitignore
.env*
!.env.example
publishProfile.xml
publishProfile*.xml
*.pubxml
*.publishsettings
```

This prevents sensitive information such as:

SQL passwords
Azure publish credentials
Storage connection strings
Application secrets

from being stored in source control.

### Production Secret Management

Secrets are managed using:

- Azure Key Vault (cloud secrets)
- Azure App Service configuration
- GitHub Actions repository secrets
- ASP.NET Core User Secrets (local development)

---

## 4. Login to Azure

You can log in manually before running the script to verify that you are using the correct Azure account and subscription:

```cmd
az login
az account show
```

> Note: The `deploy.cmd` script also calls `az login`.  
> If you are already signed in and using the correct subscription, running `deploy.cmd` directly is usually enough.

---

## 5. Azure Scope Assumptions

This deployment uses:

- A fixed Azure subscription
- A pre-created Resource Group

Therefore, the deployment script does not create a new Resource Group.


---

## 6. Run Deployment Script (deploy.cmd)

The Azure infrastructure is fully automated using the `deploy.cmd` script located in the project root.

---

### How to run the script

Open Command Prompt and execute:

```cmd
cd <project-folder>
.\deploy.cmd
```


### What the script does

The script automatically provisions and configures the full Azure environment using Azure CLI.

Below is a step-by-step explanation of the deployment process.

---

## 6.1 Environment Setup & Azure Login

- Load environment variables from `.env.local` or `.env`
- Validate required configuration
- Check Azure login status
- Verify active subscription
- Set default resource group

---

## 6.2 App Service Infrastructure

- Create App Service Plan (Linux B1)
- Create Azure Web App (.NET 10)

---

## 6.3 Azure SQL Database Setup

- Create Azure SQL Server
- Create Azure SQL Database (serverless)

---

## 6.4 Network Security Configuration

- Configure SQL firewall rules (Azure + local IP)
- Configure Web App IP access restriction

---

## 6.5 Key Vault & Secret Management

- Create Azure Key Vault
- Store SQL connection string securely
- Enable Managed Identity
- Configure Key Vault references

---

## 6.6 Monitoring, Storage & Logging

- Create Application Insights
- Enable application logging
- Create Storage Account
- Create Blob containers (images, backups)
- Store storage connection string in Key Vault

---

## 6.7 Finalization & CI/CD Setup

- Restart Web App
- Enable publishing credentials
- Export `publishProfile.xml`

The generated XML publish profile is later stored as a GitHub Actions repository secret and used for CI/CD deployment authentication.

---

# ✅ 7. Manual Post-Deployment Steps

After `deploy.cmd` has completed successfully, most Azure resources are automatically provisioned.

However, the following manual steps are still required to finalize the deployment:

- Database initialization (EF Core)
EF Core migrations must be run manually to initialize the Azure SQL schema.

- CI/CD setup (GitHub Actions)
GitHub secrets and workflows require manual configuration for secure deployments.

- Verification of Storage integration
Manual verification ensures the Storage connection via Key Vault works at runtime.

## 7.1 Apply EF Core Migrations to Azure SQL

Although Azure SQL Server and Database are created automatically, the database schema must still be initialized using EF Core migrations.

### Step 1 — Get connection string

```bash
az sql db show-connection-string ^
  --server <sql-server-name> ^
  --name <database-name> ^
  --client ado.net ^
  --output tsv
```

Replace the following placeholders using values from `.env`:

- `<username>`
- `<password>`

### Step 2 — Configure local User Secrets

```bash
dotnet user-secrets set "ConnectionStrings:DefaultConnection" "<connection-string>"
```

### Step 3 — Run EF Core migrations

```bash
dotnet ef database update
```

## 7.2 Storage Account (Verification Only)

The Storage Account and Blob containers are already created automatically by `deploy.cmd`.

No manual creation is required.

### Step 1 — Verify Storage resources

The deployment script has already created:

- Azure Storage Account
- `images` container
- `backups` container
- Storage connection string stored in Key Vault
- Web App Key Vault reference configuration

### Step 2 — Confirm Key Vault secret exists

The Storage connection string is stored in Azure Key Vault under the following secret name:

- `StorageConnectionString`

You can verify it using:

```bash
az keyvault secret show ^
  --vault-name %KV_NAME% ^
  --name StorageConnectionString
```

### Step 3 — Confirm Web App configuration

The Web App uses a Key Vault reference:

```text
ConnectionStrings__StorageAccount=@Microsoft.KeyVault(...)
```

At runtime:

- Azure App Service resolves the secret
- The Storage connection string is injected automatically
- The application accesses Blob Storage securely

### Storage usage in application

- `images` container → file uploads
- `backups` container → future backup support

## 7.3 Configure GitHub Actions Publish Profile Secret

### Step 1 — Navigate to GitHub settings

`Repository → Settings → Secrets and variables → Actions`

### Step 2 — Create secret

```text
AZURE_WEBAPP_PUBLISH_PROFILE
```

### Step 3 — Add publish profile

Paste the content of:

```text
publishProfile.xml
```

This file is generated by `deploy.cmd`.

This enables GitHub Actions to deploy to Azure App Service securely.

## 7.4 GitHub Actions CI/CD Setup

### Step 1 — Create workflow file

```text
.github/workflows/deploy.yml
```

### Step 2 — Configure pipeline

The workflow should:

- Build the ASP.NET Core project
- Publish artifacts
- Deploy to Azure Web App

### Step 3 — Ensure prerequisites

Before running CI/CD:

- `deploy.cmd` has completed successfully
- `publishProfile.xml` exists
- SCM publishing is enabled in Azure App Service

### Step 4 — Trigger deployment

```bash
git push origin main
```

GitHub Actions will automatically deploy the application.

## 🔑 Final Summary (Manual Steps)

After automated deployment, complete the following:

### Database

- Run EF Core migrations

### Storage

- Verify that the Key Vault secret exists
- Confirm that the Web App Key Vault reference works

### CI/CD

- Add the GitHub secret
- Enable GitHub Actions deployment

---

## 8. Verify Deployment

Open the deployed application:

```text
  https://YOUR_APP_NAME.azurewebsites.net
  ```

Verify that:

- The application loads correctly
- API endpoints respond successfully
- Azure SQL connection works
- Application Insights collects telemetry
- Blob Storage integration works
- Key Vault references resolve correctly

---

## 9. Backup Limitation and Optional Upgrade

This deployment uses the B1 App Service Plan for cost control in the school environment.  
Because automated App Service backup requires a higher pricing tier, backup is not configured in `deploy.cmd`.


## 9.1 Upgrade App Service Plan

```cmd
az appservice plan update ^
  --name %PLAN_NAME% ^
  --resource-group %RG% ^
  --sku S1
```

---

## 9.2 Configure One-Time Backup

```cmd
az webapp config backup create ^
  --resource-group %RG% ^
  --webapp-name %APP_NAME% ^
  --backup-name backup1 ^
  --container-url "<storage-container-sas-url>"
```

---

## 9.3 Configure Scheduled Backup

```cmd
az webapp config backup update ^
  --resource-group %RG% ^
  --webapp-name %APP_NAME% ^
  --container-url "<storage-container-sas-url>" ^
  --frequency 1d ^
  --retain-one true ^
  --retention 10
```

---

## 9.4 Verify Backup Configuration

```cmd
az webapp config backup show ^
  --resource-group %RG% ^
  --webapp-name %APP_NAME%
```

---

# Final Deployment Flow Summary

```text
1. Clone Repository  
2. Configure .env  
3. Login to Azure  
4. Run deploy.cmd  

5. Apply EF Core migrations  
   - Includes setting up SQL connection string (locally via user-secrets)

6. Configure GitHub Actions secret  
   - Includes storing publish profile for Azure deployment  
   - Storage connection string and SQL secrets are managed via Azure Key Vault

7. Push code to GitHub  
8. Verify deployment
```