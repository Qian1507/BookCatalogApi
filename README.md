# BookCatalogApi

## 1. Local Development

This section describes how the BookCatalogApi was created and tested locally before deployment to Azure. The local development environment used Visual Studio 2026 and .NET 10. The purpose of this section is to ensure that the application is fully functional before deploying it to Azure.

---

### 1. Create the project
A new ASP.NET Core Web API project was created in Visual Studio 2026 using .NET 10.

---

### 2. Install required NuGet packages
The following Entity Framework Core packages were installed:

- Microsoft.EntityFrameworkCore  
- Microsoft.EntityFrameworkCore.SqlServer  
- Microsoft.EntityFrameworkCore.Tools  

These packages are required to use Entity Framework Core with SQL Server and to create database migrations.

---

### 3. Create the model and database context
A `Book` model was created in the **Models** folder. It contains properties such as:

- Title  
- Author  
- Genre  
- Price  
- PublishedDate  

An `AppDbContext` class was created in the **Data** folder. The context exposes:

```csharp
DbSet<Book>

4. Configure the database connection

The connection string was added to appsettings.json:

{
  "ConnectionStrings": {
    "DefaultConnection": "Server=(localdb)\\MSSQLLocalDB;Database=BookCatalogDb;Trusted_Connection=True;MultipleActiveResultSets=true;TrustServerCertificate=True"
  }
}

For local development, the connection string is stored in appsettings.json.
In later stages, this will be moved to Azure Key Vault for secure configuration.

5. Register EF Core in Program.cs

AppDbContext was registered using SQL Server:

builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));
6. Configure API services

The API was configured to use controllers and built-in OpenAPI support:

builder.Services.AddControllers();
builder.Services.AddOpenApi();

In development mode, the OpenAPI document is exposed via:

app.MapOpenApi();
7. Create the database using migrations

Entity Framework Core migrations were created and applied using:

Add-Migration InitialCreate -OutputDir Data/Migrations
Update-Database

These commands created the database schema based on the Book model and AppDbContext.

8. Create the API controller

A BooksController was created in the Controllers folder.

Implemented endpoints:

GET /api/books
GET /api/books/{id}
POST /api/books
PUT /api/books/{id}
DELETE /api/books/{id}
9. Test the API locally

The API was tested using the .http file support in Visual Studio.

Example requests:

GET /api/books
POST /api/books
GET /api/books/1

A successful test means:

Correct HTTP status codes
Valid JSON responses
Data is stored and retrieved from the database
10. Local result

The application was successfully tested locally with:

ASP.NET Core Web API on .NET 10
Entity Framework Core with SQL Server
Database migrations
CRUD endpoints
Local testing via .http requests

This confirms that the application is fully functional and ready for deployment to Azure App Service.
