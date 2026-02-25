# Copilot Instructions

## Repository overview

This is a **dual-purpose repository**: a hands-on workshop (lab guide) hosted on GitHub Pages, and a sample .NET e-commerce application ("Zava Storefront") that participants build, secure, and deploy to Azure during the exercises.

## Architecture

### Workshop documentation (root)

Jekyll site using the **just-the-docs** theme. Content lives in `docs/` as numbered exercise folders (`01_*` through `07_*`). The site is built and deployed via the `jekyll-gh-pages.yml` workflow on push to `main`.

- `_config.yml` — Jekyll config; defines custom callout types (`highlight`, `important`, `new`, `note`, `warning`) used across exercise docs.
- `index.md` — Landing page (`layout: home`, `nav_order: 1`).
- `Gemfile` — Pins Jekyll 4.4.x and just-the-docs 0.10.1.

### Zava Storefront application (`src/`)

ASP.NET Core MVC app targeting **.NET 6**. No database — product data is hardcoded in `ProductService` and cart state uses ASP.NET session (in-memory, 30-minute timeout).

- **Controllers**: `HomeController` (product listing, add-to-cart), `CartController` (cart CRUD, checkout).
- **Services**: `ProductService` (singleton, static product catalog), `CartService` (scoped, session-based cart via `IHttpContextAccessor`).
- **Models**: `Product`, `CartItem` — plain POCOs in `ZavaStorefront.Models` namespace.
- **Views**: Razor views with Bootstrap 5. Layout in `Views/Shared/_Layout.cshtml`.

### Infrastructure (`infra/`)

Azure Bicep templates scoped at subscription level. `main.bicep` orchestrates modular deployments: managed identity, monitoring (Log Analytics + App Insights), ACR, AI Foundry (OpenAI + Hub + Project), App Service (Linux Docker), and RBAC role assignments. Parameterized via `main.parameters.json`.

### Azure Developer CLI

`azure.yaml` at root defines the `zava-storefront` service pointing to `./src`, hosted on App Service, language `dotnet`.

## Build and run commands

```bash
# Restore and run the .NET app
cd src
dotnet restore
dotnet run

# Build for release
dotnet build -c Release

# Publish (used in Docker build)
dotnet publish -c Release -o ./publish /p:UseAppHost=false

# Build Docker image locally
docker build -t zavastorefrontweb -f src/Dockerfile src/

# Serve the Jekyll docs site locally
bundle install
bundle exec jekyll serve
```

## CI/CD workflows

- **`jekyll-gh-pages.yml`** — Builds and deploys Jekyll site to GitHub Pages on push to `main`.
- **`build-push-acr.yml`** — Manual dispatch; builds the Docker image via `az acr build` and pushes to Azure Container Registry. Uses OIDC auth with `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` secrets and `AZURE_CONTAINER_REGISTRY_NAME` variable.

## Key conventions

- Services are registered in `Program.cs` with specific lifetimes: `ProductService` as **Singleton**, `CartService` as **Scoped**. Follow these patterns when adding new services.
- Controllers use constructor-injected `ILogger<T>` with structured logging (`LogInformation`, `LogWarning`). Include contextual parameters (e.g., `{ProductId}`, `{ItemCount}`).
- The `ZavaStorefront` namespace is the root. Sub-namespaces: `.Models`, `.Services`, `.Controllers`.
- Bicep modules go in `infra/modules/` and are wired through `infra/main.bicep` at subscription scope.
- Workshop docs use Jekyll front matter for navigation ordering. Each exercise folder has a parent page and numbered sub-pages.
