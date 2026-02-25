# Build stage
FROM mcr.microsoft.com/dotnet/sdk:8.0.417 AS build
WORKDIR /src
COPY ["ZavaStorefront.csproj", "."]
RUN dotnet restore
COPY . .
RUN dotnet publish -c Release -o /app/publish /p:UseAppHost=false

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:8.0.17 AS runtime
WORKDIR /app
COPY --from=build /app/publish .
EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080
ENTRYPOINT ["dotnet", "ZavaStorefront.dll"]
