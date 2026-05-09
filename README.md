# 📘 BookCatalogApi – Azure Deployment Project

## 1. Overview
**BookCatalogApi** is an ASP.NET Core Web API built with **.NET 10** and **Entity Framework Core**.

*   **Cloud Integration**: The project demonstrates full cloud deployment on Microsoft Azure, including compute, database, security, monitoring, and CI/CD automation.
*   **Workflow**: The system was first developed locally and then deployed to Azure App Service using automated infrastructure scripts (Azure CLI) and GitHub Actions.

---

## 2. Architecture
The application utilizes a modern cloud-native architecture:

flowchart TD

    Client[Client / Browser / API Consumer]

    subgraph AzureCloud["Azure Cloud"]
        
        AppService[Azure App Service<br/>.NET 10 Web API]

        SQL[Azure SQL Database<br/>Serverless]

        KV[Azure Key Vault<br/>Secrets Storage]

        AI[Application Insights<br/>Monitoring & Logging]

        Storage[Azure Storage Account<br/>Files / Backups]
    end

    Client --> AppService
    AppService --> SQL

    AppService --> KV
    AppService --> AI
    AppService --> Storage

    KV -. Secure Secret Access .-> AppService

  The architecture separates concerns into compute, data, security, and observability layers. 
  Sensitive information is never stored in the application code and is retrieved securely via Azure Key Vault using Managed Identity.


*   **Compute**: Azure App Service (Linux-based) hosting the Web API.
*   **Database**: Azure SQL Database (Serverless tier) for persistent storage.
*   **Secrets**: Azure Key Vault for managing sensitive credentials.
*   **Observability**: Azure Application Insights for telemetry and logging.
*   **Automation**: GitHub Actions for Continuous Integration and Deployment.

---

## 3. Technologies Used
*   **Framework**: ASP.NET Core Web API (.NET 10)
*   **ORM**: Entity Framework Core
*   **Host**: Azure App Service
*   **Database**: Azure SQL Database (Serverless)
*   **Security**: Azure Key Vault & Managed Identity
*   **Monitoring**: Azure Application Insights
*   **Storage**: Azure Storage Account
*   **Automation**: GitHub Actions & Azure CLI (Infrastructure as Code)

---

## 4. Local Development & Testing
Before moving to the cloud, the API was fully validated in a local environment.

*   **Approach**: Entity Framework Core Code-First approach.
*   **Endpoints**:
    *   `GET /api/books` - List all books.
    *   `POST /api/books` - Add a new book.
    *   `DELETE /api/books/{id}` - Remove a book.
*   **Validation**: Verified HTTP response codes (200, 201, 404) and JSON payload consistency.

---

## 5. Infrastructure as Code (Azure CLI)
All resources were provisioned using standardized scripts to ensure environment consistency.

### Provisioning Snippets:
```bash
# Create App Service with .NET 10 Runtime
az webapp create --name $APP_NAME --plan $PLAN_NAME --runtime "DOTNETCORE:10.0"

# Create Serverless SQL Database
az sql db create --server $SQL_SERVER --name $DB_NAME --edition GeneralPurpose --compute-model Serverless

6. Security Implementation
Secrets Management
Instead of hardcoding the SQL connection string in appsettings.json, I implemented Key Vault References:

Managed Identity: Enabled a System-Assigned Identity for the Web App.

Access Control: Granted Key Vault Secrets User role to the Web App's Identity.

Configuration:
  ConnectionStrings__DefaultConnection = @Microsoft.KeyVault(SecretUri=https://YOUR_KV.vault.azure.net/secrets/SqlConnectionString/)

### Network Security
*   **Firewall**: Azure SQL is configured to block all public traffic except for:
    1.  Internal Azure Services (required for the Web App).
    2.  Specific Developer IP (required for database migrations).
*   **Encryption**: HTTPS is strictly enforced (`https-only true`).

---

## 7. Monitoring & Observability
**Azure Application Insights** was integrated to provide:
*   **Request Tracking**: Monitoring successful and failed API calls.
*   **Live Metrics**: Real-time view of CPU and memory usage.
*   **Exception Logs**: Detailed stack traces for unhandled exceptions (crucial for debugging 503 errors during initial deployment).

---

## 8. CI/CD Pipeline
Continuous Deployment is handled via **GitHub Actions**. Every push to the `main` branch triggers:
1.  **Build**: Compiles the .NET 10 code and runs tests.
2.  **Package**: Creates a deployment artifact.
3.  **Deploy**: Pushes the artifact to the Azure App Service.

---

## 9. Summary
This project follows **Cloud Best Practices**:
*   **Least Privilege**: Using RBAC for resource access.
*   **Zero-Secrets in Code**: Utilizing Managed Identities and Key Vault.
*   **Automation**: Fully scripted infrastructure and automated deployments.
*   **Cost Efficiency**: Leveraging Serverless SQL for dynamic scaling.