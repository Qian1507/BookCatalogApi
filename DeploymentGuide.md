# Deployment Guide

## Deployment Architecture

The deployment provisions the following Azure resources:

- Azure App Service
- Azure SQL Database
- Azure Key Vault
- Azure Application Insights
- Azure Storage Account

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

Update `.env` with your own values:

```env
APP_NAME=
SQL_SERVER_NAME=
KV_NAME=
```

The `.env` file is used only for local deployment scripts and should never be committed to source control.  
The same applies to the `publishProfile.xml` file that is generated during deployment and later used for GitHub Actions.

Sensitive production values are stored using:

- Azure App Service configuration
- Azure Key Vault
- GitHub Actions secrets

## Security & Git Ignore Rules

The following files must NOT be committed:

- `.env` / `.env.local` – local environment variables for `deploy.cmd`
- `publishProfile.xml` – App Service publish profile generated during deployment

These files are excluded from version control using `.gitignore`:

```gitignore
.env*
!.env.example
publishProfile.xml
publishProfile*.xml
*.pubxml
*.publishsettings
```

This prevents sensitive information such as connection strings, passwords and publish credentials from being stored in Git.  
In production, secrets are managed via Azure App Service configuration, Azure Key Vault and GitHub Actions secrets instead of local files..

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

This deployment uses a fixed Azure subscription and a pre-created resource group provided by the school environment.
For that reason, the script does not create a new resource group and instead targets the predefined Azure scope.

---

## 6. Run Deployment Script

The Azure infrastructure is provisioned using the deploy.cmd script located in the project root.

The script automates the Azure deployment process using Azure CLI commands and reduces the need for manual configuration in the Azure portal.

GitHub Actions publish profile configuration still requires a one-time manual setup in GitHub repository secrets.

Run the deployment script from Command Prompt:

```cmd
.\deploy.cmd
```

The script performs the following deployment steps automatically.

### 6.1 Configure Default Resource Group

The deployment script configures the default Azure Resource Group using Azure CLI.

```cmd
az configure --defaults group=%RG%
```

The Resource Group was already provided by the school Azure subscription and therefore did not need to be created manually.

This configuration ensures that all Azure resources are deployed into the correct Azure scope.

### 6.2 Create Azure App Service Plan

An Azure App Service Plan is created to host the ASP.NET Core Web API.

```cmd
az appservice plan create ^
  --name %PLAN_NAME% ^
  --location %LOCATION% ^
  --sku B1 ^
  --is-linux
```

A Linux-based hosting plan was selected because the application targets ASP.NET Core running on Linux containers.

The B1 pricing tier was used for development and testing purposes.

### 6.3 Create Azure Web App

The Azure Web App is created using the previously created App Service Plan.

```cmd
az webapp create ^
  --name %APP_NAME% ^
  --plan %PLAN_NAME% ^
  --runtime "DOTNETCORE:10.0"
```

The Web App hosts the ASP.NET Core REST API in Azure App Service.

HTTPS-only mode is then enabled to improve transport security.

```cmd
az webapp update ^
  --name %APP_NAME% ^
  --https-only true
```
This prevents insecure HTTP traffic.

### 6.4 Create Azure SQL Server and Database

An Azure SQL Server and Azure SQL Database are created for persistent application data.

az sql server create ...
az sql db create ...

A serverless database configuration was selected to automatically reduce compute usage during idle periods and lower operational cost.

### 6.5 Configure SQL Firewall Rules

Firewall rules are configured to allow:

Azure-hosted services
Local development access

The following rule allows Azure services to access the SQL Server:

```cmd
az sql server firewall-rule create ^
  --server %SQL_SERVER_NAME% ^
  --name AllowAzureServices ^
  --start-ip-address 0.0.0.0 ^
  --end-ip-address 0.0.0.0
```
The local public IP address is automatically retrieved:

```bash
curl -s ifconfig.me
```

A second firewall rule is then created for the developer machine.

This makes it possible to run EF Core migrations locally against the Azure SQL Database.

### 6.6 Configure App Service IP Restriction

In addition to SQL firewall rules, the deployment script also adds an access restriction rule for Azure App Service.

```cmd
az webapp config access-restriction add ^
  --resource-group %RG% ^
  --name %APP_NAME% ^
  --rule-name AllowMyIp ^
  --action Allow ^
  --ip-address !MY_IP!/32 ^
  --priority 100
```

This restricts access to the Web App itself, not only to the Azure SQL Server.  
It addresses the assignment requirement that App Service IP restrictions must be considered separately from SQL firewall rules.

### 6.7 Create Azure Key Vault

Azure Key Vault is created to securely store sensitive configuration values.

```cmd
az keyvault create ^
  --name %KV_NAME% ^
  --location %LOCATION%
```

The SQL connection string is stored as a Key Vault secret instead of directly inside application configuration files.

This improves security and prevents secrets from being committed to source control.

### 6.8 Enable Managed Identity

A system-assigned Managed Identity is enabled for the Azure Web App.

```cmd
az webapp identity assign ^
  --name %APP_NAME%
```

The managed identity is granted permission to read secrets from Azure Key Vault.

This removes the need to store credentials directly inside the application.

### 6.9 Configure Key Vault Reference

The SQL connection string is exposed to the ASP.NET Core application using an Azure App Service configuration setting that references the Key Vault secret.

```cmd
az webapp config appsettings set ^
  --name %APP_NAME% ^
  --settings ConnectionStrings__DefaultConnection=@Microsoft.KeyVault(...)
```

At runtime, Azure App Service automatically resolves the Key Vault secret and injects the connection string into the application configuration.

### 6.10 Configure Application Insights

Application Insights is enabled for monitoring, diagnostics, telemetry, and error tracking.

az monitor app-insights component create ...

The generated Application Insights connection string is added to the Web App configuration settings.

This allows:

Request tracking
Dependency tracking
Exception logging
Performance monitoring

### 6.11 Configure Azure Storage Account

An Azure Storage Account and Blob Storage container are created.

az storage account create ...
az storage container create ...

The storage account can later be used for backups, uploaded files, or future Blob Storage integration.

### 6.12 Restart Azure Web App

The Web App is restarted after all configuration changes have been applied.

```cmd
az webapp restart ^
  --name %APP_NAME%
```

This ensures that all environment settings and Key Vault references are loaded correctly by the application runtime.

### 6.13 Export Publish Profile

A publish profile is exported from Azure App Service.

```cmd
az webapp deployment list-publishing-profiles ^
  --name %APP_NAME% ^
  --resource-group %RG% ^
  --xml
```

The generated XML publish profile is later stored as a GitHub Actions repository secret and used for CI/CD deployment authentication.

---

## 7. Apply EF Core Migrations to Azure SQL

After the Azure SQL Server and Database have been created by `deploy.cmd`, the schema still needs to be applied using Entity Framework Core migrations.

1. Use Azure CLI to generate the ADO.NET connection string for the Azure SQL Database:

  ```cmd
   az sql db show-connection-string --server <sql-server-name> --name <database-name> --client ado.net --output tsv
   ```

2. Copy the returned connection string and replace the placeholder values for username and password, because the generated string is a template rather than a fully populated secret.

3. Store this connection string in your local user secrets or local configuration (do not commit it to source control).

   Example for ASP.NET Core user secrets:

   ```bash
   dotnet user-secrets set "ConnectionStrings:DefaultConnection" "<paste-ado-net-connection-string-here>"
   ```

4. Run the EF Core migrations against the Azure SQL Database:

   ```bash
   dotnet ef database update
   ```

This will create/update the database schema in the Azure SQL Database using the existing EF Core migrations.

---

## 8. Configure GitHub Actions Publish Profile Secret

To enable GitHub Actions to deploy the Web API to Azure App Service, a publish profile must be exported from Azure and stored as a GitHub secret.

1. Retrieve the publish profile using Azure CLI:
    ```bash
    az webapp deployment list-publishing-profiles ^
      --name %APP_NAME% ^
      --resource-group %RG% ^
      --xml
    ```
    
2. Copy the XML output.

3. In GitHub, navigate to:

   ```text
   Repository
   → Settings
   → Secrets and variables
   → Actions
   → New repository secret
   ```

4. Create a secret with the following name:

   ```text
   AZURE_WEBAPP_PUBLISH_PROFILE
   ```

5. Paste the publish profile XML as the secret value and save.

The GitHub Actions workflow reads this secret and uses it to authenticate and deploy the application to Azure App Service.

---

## 9. GitHub Actions Workflow

The CI/CD workflow is located at:

```text
.github/workflows/deploy.yml
```

The workflow automatically:

1. Builds the ASP.NET Core project
2. Publishes deployment artifacts
3. Deploys the application to Azure App Service

---

## 10. Verify Deployment

Open the deployed application:

```text
  https://YOUR_APP_NAME.azurewebsites.net
  ```

Verify:

- The application loads correctly
- API endpoints respond successfully
- Azure SQL connection works
- Application Insights logs requests and dependencies


## 11. Backup Limitation and Optional Upgrade

This deployment uses the B1 App Service Plan for cost control in the school environment.  
Because automated App Service backup requires a higher pricing tier, backup is not configured in `deploy.cmd`.

If backup is required, the App Service Plan can first be upgraded to Standard (S1):

```cmd
az appservice plan update ^
  --name %PLAN_NAME% ^
  --resource-group %RG% ^
  --sku S1
```

After the plan has been upgraded, a backup container SAS URL must be prepared for the storage account container.  
Azure App Service backups are then configured using Azure CLI.

### One-time backup

```cmd
az webapp config backup create ^
  --resource-group %RG% ^
  --webapp-name %APP_NAME% ^
  --backup-name backup1 ^
  --container-url "<storage-container-sas-url>"
```

### Scheduled backup

```cmd
az webapp config backup update ^
  --resource-group %RG% ^
  --webapp-name %APP_NAME% ^
  --container-url "<storage-container-sas-url>" ^
  --frequency 1d ^
  --retain-one true ^
  --retention 10
```

The configured backup schedule can be verified with:

```cmd
az webapp config backup show ^
  --resource-group %RG% ^
  --webapp-name %APP_NAME%
```