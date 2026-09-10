# BakiBondhu API — container image for cloud hosting (Render / Railway / Fly / any).
# Multi-stage: build+publish with the .NET 9 SDK, run on the slim ASP.NET runtime.
# Build context must be the Backend/ folder:  docker build -t bakibondhu-api Backend

# ---- build ----
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# Restore first (cached unless a .csproj changes).
COPY BakiBondhu.sln ./
COPY BakiBondhu.Api/BakiBondhu.Api.csproj BakiBondhu.Api/
COPY BakiBondhu.Application/BakiBondhu.Application.csproj BakiBondhu.Application/
COPY BakiBondhu.Infrastructure/BakiBondhu.Infrastructure.csproj BakiBondhu.Infrastructure/
COPY BakiBondhu.Domain/BakiBondhu.Domain.csproj BakiBondhu.Domain/
RUN dotnet restore BakiBondhu.Api/BakiBondhu.Api.csproj

# Copy the rest and publish a release build.
COPY . .
RUN dotnet publish BakiBondhu.Api/BakiBondhu.Api.csproj -c Release -o /app /p:UseAppHost=false

# ---- runtime ----
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS runtime
WORKDIR /app
COPY --from=build /app ./

# The host provides $PORT (Program.cs binds to it); default to 8080 otherwise.
ENV PORT=8080
EXPOSE 8080
ENTRYPOINT ["dotnet", "BakiBondhu.Api.dll"]
