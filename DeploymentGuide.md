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

```bash
copy .env.example .env
```

Update `.env` with your own values:

```env
APP_NAME=
SQL_SERVER_NAME=
KV_NAME=
```

The `.env` file is used only for local deployment scripts and should never be committed to source control.

Sensitive production values are stored using:

- Azure App Service configuration
- Azure Key Vault

---

## 4. Login to Azure

```bash
az login
```

Verify the active subscription:

```bash
az account show
```

---

## 5. Azure Scope Assumptions

This deployment uses a fixed Azure subscription and a pre-created resource group provided by the school environment.
For that reason, the script does not create a new resource group and instead targets the predefined Azure scope.

---

## 6. Run Deployment Script

Run the deployment script from the project root:

```bash
deploy.cmd
```

The script provisions Azure infrastructure using Azure CLI.

Created resources include:

- Azure App Service
- Azure SQL Database
- Azure Key Vault
- Managed Identity
- Application Insights
- Azure Storage Account

---

## 6. Apply EF Core Migrations to Azure SQL

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

3. Run the EF Core migrations against the Azure SQL Database:

   ```bash
   dotnet ef database update
   ```

This will create/update the database schema in the Azure SQL Database using the existing EF Core migrations.

---

## 7. Configure GitHub Actions Publish Profile Secret

To enable GitHub Actions to deploy the Web API to Azure App Service, a publish profile must be exported from Azure and stored as a GitHub secret.

1. Retrieve the publish profile using Azure CLI:

    az webapp deployment list-publishing-profiles ^
      --name %APP_NAME% ^
      --resource-group %RG% ^
      --xml

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

## 8. GitHub Actions Workflow

The CI/CD workflow is located at:

```text
.github/workflows/deploy.yml
```

The workflow automatically:

1. Builds the ASP.NET Core project
2. Publishes deployment artifacts
3. Deploys the application to Azure App Service

---

## 9. Verify Deployment

Open the deployed application:

```text
https://YOUR_APP_NAME.azurewebsites.net
```

Verify:

- The application loads correctly
- API endpoints respond successfully
- Azure SQL connection works
- Application Insights logs requests and dependencies