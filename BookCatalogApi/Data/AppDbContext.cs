using BookCatalogApi.Models;
using Microsoft.EntityFrameworkCore;

namespace BookCatalogApi.Data
{
    public class AppDbContext:DbContext
    {
        public AppDbContext(DbContextOptions<AppDbContext> options)
           : base(options)
        {
        }

        public DbSet<Book> Books { get; set; }
    }
}
