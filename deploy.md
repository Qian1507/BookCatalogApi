🚀 Deployment Guide (BookCatalogApi)

This document describes how the BookCatalogApi infrastructure was deployed to Microsoft Azure using Azure CLI and GitHub Actions.

1. Prerequisites

Before deployment, ensure the following are installed and configured:

Azure CLI (latest version)
.NET 10 SDK
GitHub repository containing the Web API source code
Active Azure subscription
Login to Azure
az login
Set Default Resource Group
az configure --defaults group=YOUR_RESOURCE_GROUP
2. Create App Service

A Linux-based App Service Plan is used to host the Web API.

az appservice plan create ^
  --name YOUR_PLAN ^
  --location westeurope ^
  --sku B1 ^
  --is-linux

az webapp create ^
  --name YOUR_APP_NAME ^
  --plan YOUR_PLAN ^
  --runtime "DOTNETCORE:10.0"
3. Create Azure SQL Database

A serverless Azure SQL Database is used for cost efficiency and automatic scaling.

az sql server create ^
  --name YOUR_SQL_SERVER ^
  --location westeurope ^
  --admin-user YOUR_USER ^
  --admin-password YOUR_PASSWORD

az sql db create ^
  --server YOUR_SQL_SERVER ^
  --name YOUR_DB ^
  --edition GeneralPurpose ^
  --compute-model Serverless
4. Configure Firewall (Security)

Firewall rules are configured to control database access:

Allow Azure Services → enables App Service connectivity
Allow Local IP → enables local development and testing
az sql server firewall-rule create ^
  --server YOUR_SQL_SERVER ^
  --name AllowAzure ^
  --start-ip-address 0.0.0.0 ^
  --end-ip-address 0.0.0.0
5. Key Vault Setup & Managed Identity

Azure Key Vault is used to securely store sensitive information.

Create Key Vault
az keyvault create ^
  --name YOUR_KV ^
  --location westeurope
Store Connection String
az keyvault secret set ^
  --vault-name YOUR_KV ^
  --name SqlConnectionString ^
  --value "YOUR_CONNECTION_STRING"
Enable Managed Identity
az webapp identity assign ^
  --name YOUR_APP_NAME
Grant Access to Key Vault
az role assignment create ^
  --assignee-object-id YOUR_APP_PRINCIPAL_ID ^
  --role "Key Vault Secrets User" ^
  --scope YOUR_KV_RESOURCE_ID
6. Configure App Settings (Key Vault Reference)

The Web App retrieves the database connection string securely via Key Vault reference.

az webapp config appsettings set ^
  --name YOUR_APP_NAME ^
  --settings ConnectionStrings__DefaultConnection=@Microsoft.KeyVault(SecretUri=https://YOUR_KV.vault.azure.net/secrets/SqlConnectionString/)
7. Monitoring & Security
Application Insights

Used for logging, performance monitoring, and failure tracking.

az monitor app-insights component create ^
  --app YOUR_APP_NAME-insights ^
  --location westeurope
HTTPS Enforcement
az webapp update ^
  --name YOUR_APP_NAME ^
  --https-only true
8. CI/CD (GitHub Actions)

Deployment is automated using GitHub Actions:

Trigger: push to main branch
Build: .NET 10 project is compiled
Deploy: Artifact is deployed to Azure App Service
9. Summary

This project uses Infrastructure as Code (Azure CLI), Managed Identity, Key Vault, and CI/CD pipelines to deliver a secure, scalable, and fully automated cloud solution for the BookCatalogApi.