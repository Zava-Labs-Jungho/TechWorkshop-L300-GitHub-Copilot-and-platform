using Azure;
using Azure.AI.Inference;
using Azure.Identity;
using Azure.Security.KeyVault.Secrets;
using ZavaStorefront.Services;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllersWithViews();

// Add session support
builder.Services.AddDistributedMemoryCache();
builder.Services.AddSession(options =>
{
    options.IdleTimeout = TimeSpan.FromMinutes(30);
    options.Cookie.HttpOnly = true;
    options.Cookie.IsEssential = true;
});

// Register application services
builder.Services.AddHttpContextAccessor();
builder.Services.AddSingleton<ProductService>();
builder.Services.AddScoped<CartService>();

// Retrieve Phi-4 API key from Azure Key Vault using DefaultAzureCredential
var phi4Endpoint = builder.Configuration["Phi4:Endpoint"]
    ?? throw new InvalidOperationException("Phi4:Endpoint configuration is required.");
var keyVaultUri = builder.Configuration["KeyVault:Uri"]
    ?? throw new InvalidOperationException("KeyVault:Uri configuration is required.");
var phi4SecretName = builder.Configuration["KeyVault:Phi4SecretName"] ?? "phi4-api-key";

var credential = new DefaultAzureCredential();
var secretClient = new SecretClient(new Uri(keyVaultUri), credential);
var phi4ApiKey = secretClient.GetSecret(phi4SecretName).Value.Value;

builder.Services.AddSingleton(new ChatCompletionsClient(
    new Uri(phi4Endpoint),
    new AzureKeyCredential(phi4ApiKey)));
builder.Services.AddScoped<ChatService>();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();

app.UseRouting();

app.UseSession();

app.UseAuthorization();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

app.Run();
