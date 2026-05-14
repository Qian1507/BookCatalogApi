@echo off
setlocal enabledelayedexpansion

REM ==========================================
REM Load Environment Variables (.env.local > .env)
REM ==========================================
echo.
echo ==========================================
echo STEP 0 - Load environment variables
echo ==========================================

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

echo.
echo ==========================================
echo Loaded variables
echo ==========================================
echo RG=%RG%
echo LOCATION=%LOCATION%
echo PLAN_NAME=%PLAN_NAME%
echo APP_NAME=%APP_NAME%
echo SQL_SERVER_NAME=%SQL_SERVER_NAME%
echo DB_NAME=%DB_NAME%
echo KV_NAME=%KV_NAME%
echo STORAGE_NAME=%STORAGE_NAME%
echo ==========================================

REM ==========================================
REM Azure Login and Subscription
REM ==========================================
echo.
echo ==========================================
echo STEP 1 - Check Azure login
echo ==========================================
call az account show >nul 2>&1
if errorlevel 1 (
    echo Not logged in. Opening Azure login...
    call az login
    if errorlevel 1 (
        echo ERROR: Azure login failed
        pause
        exit /b 1
    )
)

echo.
echo ==========================================
echo STEP 2 - Show current subscription
echo ==========================================
call az account show --output table
if errorlevel 1 (
    echo ERROR: Failed to get current Azure subscription
    pause
    exit /b 1
)

echo SUCCESS: Azure login and subscription confirmed

REM ==========================================
REM Set Default Resource Group
REM ==========================================
REM Resource Group is pre-created by school (no creation needed)
echo.
echo ==========================================
echo STEP 3 - Set and verify default resource group
echo ==========================================
call az configure --defaults group=%RG%
if errorlevel 1 (
    echo ERROR: Failed to configure default resource group
    pause
    exit /b 1
)

call az group show --name %RG%
if errorlevel 1 (
    echo ERROR: Resource group %RG% not found
    pause
    exit /b 1
)

echo SUCCESS: Resource group verified

REM ==========================================
REM 1. App Service
REM ==========================================
echo.
echo ==========================================
echo STEP 4 - Create App Service Plan
echo ==========================================
call az appservice plan create ^
  --name %PLAN_NAME% ^
  --location %LOCATION% ^
  --sku B1 ^
  --is-linux
if errorlevel 1 (
    echo ERROR: Failed to create App Service Plan
    pause
    exit /b 1
)

echo SUCCESS: App Service Plan created

echo.
echo ==========================================
echo STEP 5 - Create Web App
echo ==========================================
call az webapp create ^
  --name %APP_NAME% ^
  --resource-group %RG% ^
  --plan %PLAN_NAME% ^
  --runtime "DOTNETCORE:10.0"
if errorlevel 1 (
    echo ERROR: Failed to create Web App
    pause
    exit /b 1
)

echo SUCCESS: Web App created

echo.
echo ==========================================
echo STEP 6 - Enable HTTPS only
echo ==========================================
call az webapp update ^
  --resource-group %RG% ^
  --name %APP_NAME% ^
  --https-only true
if errorlevel 1 (
    echo ERROR: Failed to enable HTTPS on Web App
    pause
    exit /b 1
)

echo SUCCESS: HTTPS enabled

REM ==========================================
REM 2. Azure SQL
REM ==========================================
echo.
echo ==========================================
echo STEP 7 - Create Azure SQL Server
echo ==========================================
call az sql server create ^
  --name %SQL_SERVER_NAME% ^
  --resource-group %RG% ^
  --location %LOCATION% ^
  --admin-user %SQL_ADMIN_USER% ^
  --admin-password %SQL_ADMIN_PASSWORD%
if errorlevel 1 (
    echo ERROR: Failed to create Azure SQL Server
    pause
    exit /b 1
)

echo SUCCESS: Azure SQL Server created

echo.
echo ==========================================
echo STEP 8 - Create Azure SQL Database
echo ==========================================
call az sql db create ^
  --resource-group %RG% ^
  --server %SQL_SERVER_NAME% ^
  --name %DB_NAME% ^
  --edition GeneralPurpose ^
  --compute-model Serverless ^
  --family Gen5 ^
  --capacity 2 ^
  --min-capacity 0.5 ^
  --auto-pause-delay 15
if errorlevel 1 (
    echo ERROR: Failed to create Azure SQL Database
    pause
    exit /b 1
)

echo SUCCESS: Azure SQL Database created

REM ==========================================
REM 3. SQL Firewall Rules
REM ==========================================
echo.
echo ==========================================
echo STEP 9 - Add SQL firewall rule for Azure services
echo ==========================================
call az sql server firewall-rule create ^
  --server %SQL_SERVER_NAME% ^
  --name AllowAzureServices ^
  --start-ip-address 0.0.0.0 ^
  --end-ip-address 0.0.0.0
if errorlevel 1 (
    echo ERROR: Failed to add firewall rule for Azure services
    pause
    exit /b 1
)

echo SUCCESS: Azure services firewall rule added

echo.
echo ==========================================
echo STEP 10 - Detect current public IP
echo ==========================================
for /f %%i in ('curl -s https://ipv4.icanhazip.com') do set MY_IP=%%i

if "!MY_IP!"=="" (
    echo ERROR: Failed to detect public IPv4 address
    pause
    exit /b 1
)

echo Current public IPv4: !MY_IP!

echo.
echo ==========================================
echo STEP 11 - Add SQL firewall rule for current IP
echo ==========================================
call az sql server firewall-rule create ^
  --server %SQL_SERVER_NAME% ^
  --name AllowMyIp ^
  --start-ip-address !MY_IP! ^
  --end-ip-address !MY_IP!
if errorlevel 1 (
    echo ERROR: Failed to add firewall rule for current IP
    pause
    exit /b 1
)

echo SUCCESS: Current IP firewall rule added

REM ==========================================
REM 4. App Service IP Restriction
REM ==========================================
echo.
echo ==========================================
echo STEP 12 - Add Web App access restriction for current IP
echo ==========================================
call az webapp config access-restriction add ^
  --resource-group %RG% ^
  --name %APP_NAME% ^
  --rule-name AllowMyIp ^
  --action Allow ^
  --ip-address !MY_IP!/32 ^
  --priority 100
if errorlevel 1 (
    echo ERROR: Failed to add Web App access restriction
    pause
    exit /b 1
)

echo SUCCESS: Web App access restriction added

REM ==========================================
REM 5. Key Vault + Identity
REM ==========================================
echo.
echo ==========================================
echo STEP 13 - Create Key Vault
echo ==========================================
call az keyvault create ^
  --name %KV_NAME% ^
  --resource-group %RG% ^
  --location %LOCATION%
if errorlevel 1 (
    echo ERROR: Failed to create Key Vault
    pause
    exit /b 1
)

echo SUCCESS: Key Vault created

echo.
echo ==========================================
echo STEP 14 - Resolve user object ID and Key Vault resource ID
echo ==========================================
for /f "delims=" %%i in ('call az ad signed-in-user show --query id --output tsv') do set MY_OBJECT_ID=%%i
for /f "delims=" %%i in ('call az keyvault show --name %KV_NAME% --query id --output tsv') do set KV_RESOURCE_ID=%%i

if "%MY_OBJECT_ID%"=="" (
    echo ERROR: Failed to get signed-in user object ID
    pause
    exit /b 1
)

if "%KV_RESOURCE_ID%"=="" (
    echo ERROR: Failed to get Key Vault resource ID
    pause
    exit /b 1
)

echo SUCCESS: Required IDs resolved

echo.
echo ==========================================
echo STEP 15 - Assign Key Vault Secrets Officer role to current user
echo ==========================================
call az role assignment create ^
  --assignee-object-id %MY_OBJECT_ID% ^
  --role "Key Vault Secrets Officer" ^
  --scope %KV_RESOURCE_ID%
if errorlevel 1 (
    echo ERROR: Failed to assign Key Vault Secrets Officer role
    pause
    exit /b 1
)

echo SUCCESS: Key Vault role assigned to current user

REM Build SQL connection string into a file to avoid CMD escaping issues
(
  echo Server=tcp:%SQL_SERVER_NAME%.database.windows.net,1433;Initial Catalog=%DB_NAME%;Persist Security Info=False;User ID=%SQL_ADMIN_USER%;Password=%SQL_ADMIN_PASSWORD%;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;
) > sql-connection-string.txt

echo.
echo ==========================================
echo STEP 16 - Store SQL connection string in Key Vault
echo ==========================================
call az keyvault secret set ^
  --vault-name %KV_NAME% ^
  --name SqlConnectionString ^
  --file sql-connection-string.txt
if errorlevel 1 (
    echo ERROR: Failed to store SQL connection string in Key Vault
    del sql-connection-string.txt
    pause
    exit /b 1
)

del sql-connection-string.txt
echo SUCCESS: SQL connection string stored in Key Vault

echo.
echo ==========================================
echo STEP 17 - Enable Managed Identity on Web App
echo ==========================================
call az webapp identity assign ^
  --name %APP_NAME% ^
  --resource-group %RG%
if errorlevel 1 (
    echo ERROR: Failed to enable Managed Identity on Web App
    pause
    exit /b 1
)

echo SUCCESS: Managed Identity enabled
echo Waiting for Managed Identity propagation...
timeout /t 20 /nobreak >nul


echo.
echo ==========================================
echo STEP 18 - Resolve Web App principal ID
echo ==========================================
for /f "delims=" %%i in ('call az webapp identity show --name %APP_NAME% --resource-group %RG% --query principalId --output tsv') do set "APP_PRINCIPAL_ID=%%i"

echo APP_PRINCIPAL_ID=[%APP_PRINCIPAL_ID%]

if "%APP_PRINCIPAL_ID%"=="" (
    echo ERROR: Failed to get Web App principal ID
    pause
    exit /b 1
)

echo SUCCESS: Web App principal ID resolved

echo.
echo ==========================================
echo STEP 19 - Assign Key Vault Secrets User role to Web App
echo ==========================================
call az role assignment create ^
  --assignee-object-id "%APP_PRINCIPAL_ID%" ^
  --assignee-principal-type ServicePrincipal ^
  --role "Key Vault Secrets User" ^
  --scope "%KV_RESOURCE_ID%"
if errorlevel 1 (
    echo ERROR: Failed to assign Key Vault Secrets User role to Web App
    pause
    exit /b 1
)

echo SUCCESS: Web App access to Key Vault granted

echo.
echo ==========================================
echo STEP 20 - Configure Key Vault reference in Web App settings
echo ==========================================
call az webapp config appsettings set ^
  --name %APP_NAME% ^
  --resource-group %RG% ^
  --settings ConnectionStrings__DefaultConnection=@Microsoft.KeyVault(SecretUri=https://%KV_NAME%.vault.azure.net/secrets/SqlConnectionString/)
if errorlevel 1 (
    echo ERROR: Failed to configure Key Vault reference in Web App settings
    pause
    exit /b 1
)

echo SUCCESS: Key Vault reference configured

REM ==========================================
REM 6. Application Insights
REM ==========================================
echo.
echo ==========================================
echo STEP 21 - Create Application Insights
echo ==========================================
call az monitor app-insights component create ^
  --app %APP_NAME%-insights ^
  --location %LOCATION% ^
  --resource-group %RG%
if errorlevel 1 (
    echo ERROR: Failed to create Application Insights
    pause
    exit /b 1
)

echo SUCCESS: Application Insights created

echo.
echo ==========================================
echo STEP 22 - Get Application Insights connection string
echo ==========================================
for /f "delims=" %%i in ('call az monitor app-insights component show --app %APP_NAME%-insights --query connectionString -o tsv') do set AI_CONN=%%i

if "!AI_CONN!"=="" (
    echo ERROR: Failed to get Application Insights connection string
    pause
    exit /b 1
)

echo SUCCESS: Application Insights connection string resolved

echo.
echo ==========================================
echo STEP 23 - Configure Application Insights in Web App settings
echo ==========================================
call az webapp config appsettings set ^
  --name %APP_NAME% ^
  --resource-group %RG% ^
  --settings APPLICATIONINSIGHTS_CONNECTION_STRING=!AI_CONN!
if errorlevel 1 (
    echo ERROR: Failed to set Application Insights connection string
    pause
    exit /b 1
)

echo SUCCESS: Application Insights configured

REM ==========================================
REM 7. Logging
REM ==========================================
echo.
echo ==========================================
echo STEP 24 - Enable application logging
echo ==========================================
call az webapp log config ^
  --name %APP_NAME% ^
  --resource-group %RG% ^
  --application-logging filesystem ^
  --level verbose
if errorlevel 1 (
    echo ERROR: Failed to enable application logging
    pause
    exit /b 1
)

echo SUCCESS: Application logging enabled

echo.
echo ==========================================
echo STEP 25 - Enable web server logging
echo ==========================================
call az webapp log config ^
  --name %APP_NAME% ^
  --resource-group %RG% ^
  --web-server-logging filesystem
if errorlevel 1 (
    echo ERROR: Failed to enable web server logging
    pause
    exit /b 1
)

echo SUCCESS: Web server logging enabled

REM ==========================================
REM 8. Storage Account
REM ==========================================
echo.
echo ==========================================
echo STEP 26 - Create Storage Account
echo ==========================================
call az storage account create ^
  --name %STORAGE_NAME% ^
  --resource-group %RG% ^
  --location %LOCATION% ^
  --sku Standard_LRS
if errorlevel 1 (
    echo ERROR: Failed to create Storage Account
    pause
    exit /b 1
)

echo SUCCESS: Storage Account created

echo.
echo ==========================================
echo STEP 27 - Create backup container
echo ==========================================
call az storage container create ^
  --name backups ^
  --account-name %STORAGE_NAME% ^
  --auth-mode login
if errorlevel 1 (
    echo ERROR: Failed to create backup container
    pause
    exit /b 1
)

echo SUCCESS: Backup container created

REM ==========================================
REM 9. Restart App
REM ==========================================
echo.
echo ==========================================
echo STEP 28 - Restart Web App
echo ==========================================
call az webapp restart ^
  --name %APP_NAME% ^
  --resource-group %RG%
if errorlevel 1 (
    echo ERROR: Failed to restart Web App
    pause
    exit /b 1
)

echo SUCCESS: Web App restarted

REM ==========================================
REM 10. Publish Profile (GitHub Actions)
REM ==========================================
echo.
echo ==========================================
echo STEP 29 - Export publish profile
echo ==========================================
call az webapp deployment list-publishing-profiles ^
  --name %APP_NAME% ^
  --resource-group %RG% ^
  --xml > publishProfile.xml
if errorlevel 1 (
    echo ERROR: Failed to export publish profile
    pause
    exit /b 1
)

echo SUCCESS: Publish profile exported

echo.
echo ==========================================
echo Deployment completed successfully
echo Publish profile saved to publishProfile.xml
echo.
echo Next Step:
echo Copy publishProfile.xml content into:
echo GitHub -> Settings -> Secrets -> Actions
echo Secret Name: AZURE_WEBAPP_PUBLISH_PROFILE
echo ==========================================
pause
exit /b 0


