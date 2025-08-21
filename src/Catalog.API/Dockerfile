# Use the official .NET 9 runtime image as the base image
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS base
WORKDIR /app
EXPOSE 80
EXPOSE 443

# Use the official .NET 9 SDK image for building
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# Copy the entire source directory
COPY . .

# Restore dependencies for the specific project
RUN dotnet restore "Catalog.API/Catalog.API.csproj"

# Build the application
RUN dotnet build "Catalog.API/Catalog.API.csproj" -c Release -o /app/build

# Publish the application
FROM build AS publish
RUN dotnet publish "Catalog.API/Catalog.API.csproj" -c Release -o /app/publish

# Build the runtime image
FROM base AS final
WORKDIR /app

# Copy the published application
COPY --from=publish /app/publish .

# Set the entry point
ENTRYPOINT ["dotnet", "Catalog.API.dll"]

