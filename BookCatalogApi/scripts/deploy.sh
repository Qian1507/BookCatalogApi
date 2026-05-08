#!/bin/bash

# ==========================================
# Azure Login
# ==========================================

az login

# ==========================================
# Default Resource Group
# ==========================================

az configure --defaults group="YOUR-RESOURCE-GROUP"

# ==========================================
# App Service Plan
# ==========================================

az appservice plan create \
  --name <app-server-plan-name> \
  --location westeurope \
  --sku B1 \
  --is-linux

# ==========================================
# Web App
# ==========================================

az webapp create \
  --name <app-service-name> \
  --plan <app-server-plan-name> \
  --runtime "DOTNETCORE:10.0"

# ==========================================
# Azure SQL Server
# ==========================================

az sql server create \
  --name <sql-server-name> \
  --location westeurope \
  --admin-user <admin-user> \
  --admin-password "<strong-password>"

# ==========================================
# Azure SQL Database
# ==========================================

az sql db create \
  --server <sql-server-name> \
  --name <database-name> \
  --edition GeneralPurpose \
  --compute-model Serverless \
  --family Gen5 \
  --capacity 2 \
  --min-capacity 0.5 \
  --auto-pause-delay 60

# ==========================================
# Allow Azure Services
# ==========================================

az sql server firewall-rule create \
  --server <sql-server-name> \
  --name AllowAzure \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0

# ==========================================
# Allow Local Machine IP
# ==========================================

MY_IP=$(curl -s ifconfig.me)

az sql server firewall-rule create \
  --server <sql-server-name> \
  --name AllowMyIp \
  --start-ip-address $MY_IP \
  --end-ip-address $MY_IP

# ==========================================
# Configure Connection String
# ==========================================

az webapp config connection-string set \
  --name <app-service-name> \
  --connection-string-type SQLAzure \
  --settings DefaultConnection="Server=tcp:<sql-server-name>.database.windows.net,1433;Initial Catalog=<database-name>;Persist Security Info=False;User ID=<sql-admin-user>;Password=<sql-admin-password>;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;"

# ==========================================
# Force HTTPS
# ==========================================

az webapp update \
  --name <app-service-name> \
  --https-only true