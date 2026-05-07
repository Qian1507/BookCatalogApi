az login

az configure --defaults group="YOUR-resource-group-NAME"

az appservice plan create --name bookcatalogapi-asp --location westeurope --sku F1 --is-linux


az webapp create --name bookcatalogapi-qian --plan bookcatalogapi-asp --runtime "DOTNETCORE:10.0"




in VS

dotnet publish -c Release -o publish

Compress-Archive -Path .\publish\* -DestinationPath .\publish.zip -Force



az webapp deploy --name bookcatalogapi-qian --src-path "C:Molnlösningar\BookCatalogApi\publish.zip" 




az webapp browse --name bookcatalogapi-qian
