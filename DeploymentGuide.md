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

## 7. Apply EF Core Migrations to Azure SQL

After the Azure SQL Server and Database have been created by `deploy.cmd`, the schema still needs to be applied using Entity Framework Core migrations.

 1  Get connection string using Azure CLI:

  ```cmd
   az sql db show-connection-string --server <sql-server-name> --name <database-name> --client ado.net --output tsv
   ```

 2  Configure local secret using ASP.NET Core User Secrets:


   ```bash
   dotnet user-secrets set "ConnectionStrings:DefaultConnection" "<paste-ado-net-connection-string-here>"
   ```

 3 Run the EF Core migrations:

   ```bash
   dotnet ef database update
   ```

This will create/update the database schema in the Azure SQL Database using the existing EF Core migrations.

---

## 8. Configure GitHub Actions Publish Profile Secret

Navigate to:

```text
Repository
→ Settings
→ Secrets and variables
→ Actions
```

Create a repository secret:

```text
AZURE_WEBAPP_PUBLISH_PROFILE
```

Paste the contents of:

```text
publishProfile.xml
```

as the secret value.



The GitHub Actions workflow reads this secret and uses it to authenticate and deploy the application to Azure App Service.

---

## 9. GitHub Actions Workflow (CI/CD Setup)

---

### Step 1 - Create workflow file

Create file:

```text
.github/workflows/deploy.yml
```

### Step 2 - Configure workflow and Azure deployment

Configure the workflow to:

1. Builds the ASP.NET Core project
2. Publishes deployment artifacts
3. Deploys the application to Azure App Service

Before this step, ensure SCM publishing is enabled in Azure App Service (handled in `deploy.cmd`), so the publish profile can be exported:

```text
publishProfile.xml
```

### Step 3 - Run CI/CD pipeline

Push code to GitHub to trigger automatic build and deployment via GitHub Actions.



---

## 10. Verify Deployment

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

## 11. Backup Limitation and Optional Upgrade

This deployment uses the B1 App Service Plan for cost control in the school environment.  
Because automated App Service backup requires a higher pricing tier, backup is not configured in `deploy.cmd`.


## 11.1 Upgrade App Service Plan

```cmd
az appservice plan update ^
  --name %PLAN_NAME% ^
  --resource-group %RG% ^
  --sku S1
```

---

## 11.2 Configure One-Time Backup

```cmd
az webapp config backup create ^
  --resource-group %RG% ^
  --webapp-name %APP_NAME% ^
  --backup-name backup1 ^
  --container-url "<storage-container-sas-url>"
```

---

## 11.3 Configure Scheduled Backup

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

## 11.4 Verify Backup Configuration

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