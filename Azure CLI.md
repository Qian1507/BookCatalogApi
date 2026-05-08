az login

az configure --defaults group="YOUR-RESOURCE-GROUP-NAME"


az appservice plan create --name <app-server-plan-name> --location westeurope --sku F1 --is-linux


az webapp create --name <app-service-name> --plan <app-server-plan-name> --runtime "DOTNETCORE:10.0"

# Create SQL Service
az sql server create \
  --name <sql-server-name> \
  --location westeurope \
  --admin-user <admin-user> \
  --admin-password "<strong-password>"

# Create serverless SQL Database
az sql db create \
  --server <sql-server-name> \
  --name <database-name> \
  --edition GeneralPurpose \
  --compute-model Serverless \
  --family Gen5 \
  --capacity 2 \
  --min-capacity 0.5 \
  --auto-pause-delay 60


  az sql db show-connection-string --server <sql-server-name> --name <database-name> -c ado.net -a SqlPassword


  paste connection-string in backend user secret

az webapp config connection-string set \
  --name <app-service-name> \
  --connection-string-type SQLAzure
  --settings AZURE_SQL_CONNECTIONSTRING="Server=tcp:<sql-server-name>.database.windows.net,1433;Initial Catalog=<database-name>;Persist Security Info=False;User ID=<sql-admin-user>;Password=<sql-admin-password>;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;" \
  

dotnet ef database update








az webapp browse --name 
