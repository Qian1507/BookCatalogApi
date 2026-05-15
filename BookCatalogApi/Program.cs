using Azure.Storage.Blobs;
using BookCatalogApi.Data;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.

builder.Services.AddControllers();

//Add services to the application insights telemetry.
builder.Services.AddApplicationInsightsTelemetry();

builder.Services.AddSingleton(x =>
    new BlobServiceClient(
        builder.Configuration.GetConnectionString("StorageAccount")));

builder.Services.AddDbContext<AppDbContext>(options => options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

builder.Services.AddOpenApi();

var app = builder.Build();

app.MapOpenApi();

app.UseDefaultFiles();
app.UseStaticFiles();

app.UseHttpsRedirection();

app.UseAuthorization();

app.MapControllers();

app.Run();
