@echo off
setlocal enabledelayedexpansion

REM ==========================================
REM Load Environment Variables (.env.local > .env)
REM ==========================================

if exist ".env.local" (
    echo Using .env.local
    set ENV_FILE=.env.local
) else (
    echo Using .env
    set ENV_FILE=.env
)

if not exist "%ENV_FILE%" (
    echo ERROR: No .env or .env.local file found
    exit /b 1
)


for /f "usebackq tokens=1,* delims==" %%A in ("%ENV_FILE%") do (
    if not "%%A"=="" if not "%%A:~0,1"=="#" (
        set "%%A=%%B"
    )
)


REM ==========================================
REM Azure Login
REM ==========================================
az login

REM Variables are loaded from .env
REM DO NOT override here

REM Fixed subscription provided by school
az account set --subscription %AZURE_SUBSCRIPTION_ID%
az account show

REM ==========================================
REM Set Default Resource Group
REM ==========================================
REM Resource Group is pre-created by school (no creation needed)
az configure --defaults group=%RG%

REM ==========================================
REM 1. App Service
REM ==========================================
az appservice plan create ^
  --name %PLAN_NAME% ^
  --location %LOCATION% ^
  --sku B1 ^
  --is-linux

az webapp create ^
  --name %APP_NAME% ^
  --plan %PLAN_NAME% ^
  --runtime "DOTNETCORE:10.0"

az webapp update ^
  --name %APP_NAME% ^
  --https-only true

REM ==========================================
REM 2. Azure SQL
REM ==========================================
az sql server create ^
  --name %SQL_SERVER_NAME% ^
  --resource-group %RG% ^
  --location %LOCATION% ^
  --admin-user %SQL_ADMIN_USER% ^
  --admin-password %SQL_ADMIN_PASSWORD%

az sql db create ^
  --server %SQL_SERVER_NAME% ^
  --name %DB_NAME% ^
  --edition GeneralPurpose ^
  --compute-model Serverless ^
  --family Gen5 ^
  --capacity 2 ^
  --auto-pause-delay 15

REM ==========================================
REM 3. SQL Firewall Rules
REM ==========================================
az sql server firewall-rule create ^
  --server %SQL_SERVER_NAME% ^
  --name AllowAzureServices ^
  --start-ip-address 0.0.0.0 ^
  --end-ip-address 0.0.0.0

for /f %%i in ('curl -s ifconfig.me') do set MY_IP=%%i

az sql server firewall-rule create ^
  --server %SQL_SERVER_NAME% ^
  --name AllowMyIp ^
  --start-ip-address !MY_IP! ^
  --end-ip-address !MY_IP!

REM ==========================================
REM 4. App Service IP Restriction
REM ==========================================
az webapp config access-restriction add ^
  --resource-group %RG% ^
  --name %APP_NAME% ^
  --rule-name AllowMyIp ^
  --action Allow ^
  --ip-address !MY_IP!/32 ^
  --priority 100


REM ==========================================
REM 5. Key Vault + Identity
REM ==========================================
az keyvault create ^
  --name %KV_NAME% ^
  --resource-group %RG% ^
  --location %LOCATION%

for /f "delims=" %%i in ('az ad signed-in-user show --query id --output tsv') do set MY_OBJECT_ID=%%i
for /f "delims=" %%i in ('az keyvault show --name %KV_NAME% --query id --output tsv') do set KV_RESOURCE_ID=%%i

az role assignment create ^
  --assignee-object-id %MY_OBJECT_ID% ^
  --role "Key Vault Secrets Officer" ^
  --scope %KV_RESOURCE_ID%


REM Build SQL connection string
set SQL_CONNECTION_STRING=Server=tcp:%SQL_SERVER_NAME%.database.windows.net,1433;Initial Catalog=%DB_NAME%;Persist Security Info=False;User ID=%SQL_ADMIN_USER%;Password=%SQL_ADMIN_PASSWORD%;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;

REM Store SQL connection string in Key Vault
az keyvault secret set ^
  --vault-name %KV_NAME% ^
  --name SqlConnectionString ^
  --value "%SQL_CONNECTION_STRING%"


REM Enable Managed Identity
az webapp identity assign ^
  --name %APP_NAME% ^
  --resource-group %RG%

for /f "delims=" %%i in ('az webapp identity show --name %APP_NAME% --resource-group %RG% --query principalId --output tsv') do set APP_PRINCIPAL_ID=%%i

az role assignment create ^
  --assignee-object-id %APP_PRINCIPAL_ID% ^
  --role "Key Vault Secrets User" ^
  --scope %KV_RESOURCE_ID%

REM Key Vault reference
az webapp config appsettings set ^
  --name %APP_NAME% ^
  --resource-group %RG% ^
  --settings ConnectionStrings__DefaultConnection=@Microsoft.KeyVault(SecretUri=https://%KV_NAME%.vault.azure.net/secrets/SqlConnectionString/)

REM ==========================================
REM 6. Application Insights
REM ==========================================
az monitor app-insights component create ^
  --app %APP_NAME%-insights ^
  --location %LOCATION% ^
  --resource-group %RG%

for /f "delims=" %%i in ('az monitor app-insights component show --app %APP_NAME%-insights --query connectionString -o tsv') do set AI_CONN=%%i

az webapp config appsettings set ^
  --name %APP_NAME% ^
  --resource-group %RG% ^
  --settings APPLICATIONINSIGHTS_CONNECTION_STRING=!AI_CONN!

REM ==========================================
REM 7. Logging
REM ==========================================
az webapp log config ^
  --name %APP_NAME% ^
  --resource-group %RG% ^
  --application-logging true ^
  --level verbose

az webapp log config ^
  --name %APP_NAME% ^
  --resource-group %RG% ^
  --web-server-logging filesystem

REM ==========================================
REM 8. Storage Account
REM ==========================================
az storage account create ^
  --name %STORAGE_NAME% ^
  --resource-group %RG% ^
  --location %LOCATION% ^
  --sku Standard_LRS

az storage container create ^
  --name backups ^
  --account-name %STORAGE_NAME% ^
  --auth-mode login

REM ==========================================
REM 9. Restart App
REM ==========================================
az webapp restart ^
  --name %APP_NAME% ^
  --resource-group %RG%

REM ==========================================
REM 10. Publish Profile (GitHub Actions)
REM ==========================================
az webapp deployment list-publishing-profiles ^
  --name %APP_NAME% ^
  --resource-group %RG% ^
  --xml > publishProfile.xml

echo.
echo ==========================================
echo Deployment completed successfully
echo Publish profile saved to publishProfile.xml
echo ==========================================

pause