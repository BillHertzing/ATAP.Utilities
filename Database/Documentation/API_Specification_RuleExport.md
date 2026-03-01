# Rule Export API Specification

## Overview

This document describes the proposed REST API design for exporting Rules from the ATAPUtilities database. The API will leverage the existing stored procedure `dbo.GetRuleByName` and provide both JSON and text-based Rule exports.

## Base URL

```
https://api.atap-utilities.example.com/v1
```

## Authentication

All API endpoints require authentication using:

- **Bearer Token** (JWT recommended)
- **API Key** (header: `X-API-Key`)

Example:

```http
Authorization: Bearer <jwt_token>
```

---

## Endpoints

### 1. Get Rule by Name (JSON)

Retrieves a Rule with all metadata in JSON format.

**Endpoint:** `GET /rules/{ruleName}`

**URL Parameters:**

- `ruleName` (required): The name of the Rule (URL-encoded if contains special characters)

**Query Parameters:**

- `languageKind` (optional): Filter by language kind
  - Valid values: `CSharp`, `Powershell`, `SQL`, `MSBuild`
  - Default: All language kinds
- `includeComposition` (optional): Include primitive composition details
  - Type: boolean
  - Default: `true`
- `includeTimeBlocks` (optional): Include Philote time blocks
  - Type: boolean
  - Default: `false`
- `includeRuleSets` (optional): Include Rule Sets that contain this Rule
  - Type: boolean
  - Default: `false`

**Request Example:**

```http
GET /rules/%3Ccs-source-file%3E?languageKind=CSharp&includeComposition=true
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Response Example (200 OK):**

```json
{
  "success": true,
  "data": {
    "philoteId": "4f6dbde9-52f2-4d3f-82a1-7b9f3a6c4d85",
    "ruleName": "<cs-source-file>",
    "languageKind": "CSharp",
    "purpose": "Top-level container for a .cs file. A C# source file is a sequence of using directives followed by one or more namespace or type declarations.",
    "sourceFileReference": "SolutionDocumentation/Rules Compendium.CSharp.md",
    "createdAt": "2026-01-15T10:00:00Z",
    "composition": [
      {
        "sequenceKey": "1",
        "primitiveName": "<file-element-list>",
        "primitiveDescription": "List of file elements",
        "bnfDefinition": "<file-element-list> ::= <file-element>\n              | <file-element-list> <file-element>",
        "boundInputs": {
          "Elements": "ordered list of file-element instances"
        },
        "notes": null,
        "attribution": "ECMA-334 C# Language Specification"
      }
    ],
    "additionalIds": [],
    "timeBlocks": []
  }
}
```

**Error Responses:**

_404 Not Found:_

```json
{
  "success": false,
  "error": {
    "code": "RULE_NOT_FOUND",
    "message": "No Rule found with name '<non-existent-rule>' and language kind 'CSharp'"
  }
}
```

_400 Bad Request:_

```json
{
  "success": false,
  "error": {
    "code": "INVALID_PARAMETER",
    "message": "Invalid languageKind parameter. Valid values: CSharp, Powershell, SQL, MSBuild"
  }
}
```

_401 Unauthorized:_

```json
{
  "success": false,
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Invalid or missing authentication token"
  }
}
```

---

### 2. Export Rule to Text File

Generates a formatted text file export of a Rule and returns the file or a download link.

**Endpoint:** `GET /rules/{ruleName}/export`

**URL Parameters:**

- `ruleName` (required): The name of the Rule

**Query Parameters:**

- `languageKind` (optional): Filter by language kind
- `format` (optional): Output format
  - Valid values: `text`, `markdown`
  - Default: `text`
- `includeComposition` (optional): Include composition details
  - Type: boolean
  - Default: `true`

**Request Example:**

```http
GET /rules/%3Ccs-source-file%3E/export?languageKind=CSharp&format=text
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Response Example (200 OK):**

_Option A: Direct file download_

```http
HTTP/1.1 200 OK
Content-Type: text/plain; charset=utf-8
Content-Disposition: attachment; filename="Rule_cs-source-file_20260227_143000.txt"

================================================================================
Rule Export from ATAPUtilities Database
Generated: 2026-02-27 14:30:00
================================================================================

RULE INFORMATION
--------------------------------------------------------------------------------
PhiloteID:            4f6dbde9-52f2-4d3f-82a1-7b9f3a6c4d85
Rule Name:            <cs-source-file>
Language Kind:        CSharp
...
```

_Option B: Download URL (for large files)_

```json
{
  "success": true,
  "data": {
    "downloadUrl": "https://api.atap-utilities.example.com/v1/downloads/temp/rule_abc123.txt",
    "expiresAt": "2026-02-27T15:30:00Z",
    "fileSize": 12345,
    "format": "text"
  }
}
```

---

### 3. List All Rules

Retrieves a paginated list of all available Rules.

**Endpoint:** `GET /rules`

**Query Parameters:**

- `languageKind` (optional): Filter by language kind
- `page` (optional): Page number (1-based)
  - Type: integer
  - Default: 1
- `pageSize` (optional): Number of items per page
  - Type: integer
  - Default: 50
  - Max: 200
- `search` (optional): Search in rule names and purposes
  - Type: string
- `sortBy` (optional): Sort field
  - Valid values: `name`, `languageKind`, `createdAt`
  - Default: `name`
- `sortOrder` (optional): Sort direction
  - Valid values: `asc`, `desc`
  - Default: `asc`

**Request Example:**

```http
GET /rules?languageKind=CSharp&page=1&pageSize=20&sortBy=name
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Response Example (200 OK):**

```json
{
  "success": true,
  "data": {
    "rules": [
      {
        "philoteId": "4f6dbde9-52f2-4d3f-82a1-7b9f3a6c4d85",
        "ruleName": "<cs-source-file>",
        "languageKind": "CSharp",
        "purpose": "Top-level container for a .cs file...",
        "createdAt": "2026-01-15T10:00:00Z"
      },
      {
        "philoteId": "8b9e0f19-5272-4c1f-90db-e1e6b0c5d3f2",
        "ruleName": "<using-directive>",
        "languageKind": "CSharp",
        "purpose": "Imports a namespace, static members...",
        "createdAt": "2026-01-15T10:05:00Z"
      }
    ],
    "pagination": {
      "page": 1,
      "pageSize": 20,
      "totalPages": 5,
      "totalItems": 87
    }
  }
}
```

---

### 4. Get Rule by PhiloteID

Retrieves a Rule using its unique PhiloteID instead of name.

**Endpoint:** `GET /rules/by-id/{philoteId}`

**URL Parameters:**

- `philoteId` (required): The PhiloteID (GUID) of the Rule

**Query Parameters:**
Same as "Get Rule by Name" endpoint

**Request Example:**

```http
GET /rules/by-id/4f6dbde9-52f2-4d3f-82a1-7b9f3a6c4d85
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Response:** Same structure as "Get Rule by Name"

---

### 5. Batch Export Rules

Exports multiple Rules in a single request, returning a ZIP file containing all exported text files.

**Endpoint:** `POST /rules/batch-export`

**Request Body:**

```json
{
  "rules": [
    {
      "ruleName": "<cs-source-file>",
      "languageKind": "CSharp"
    },
    {
      "ruleName": "<using-directive>",
      "languageKind": "CSharp"
    }
  ],
  "format": "text",
  "includeComposition": true
}
```

**Response Example (200 OK):**

```http
HTTP/1.1 200 OK
Content-Type: application/zip
Content-Disposition: attachment; filename="rules_export_20260227_143000.zip"

[Binary ZIP file content]
```

---

## Implementation Notes

### Backend Technology Stack

**Option 1: ASP.NET Core Web API (Recommended)**

- Use existing C# ecosystem
- Direct SQL Server connectivity via Entity Framework Core or Dapper
- Call stored procedure `dbo.GetRuleByName`
- Serialize results to JSON or format as text

**Option 2: Node.js with Express**

- Use `mssql` package for SQL Server connectivity
- Good for lighter-weight API

**Option 3: Python with FastAPI**

- Use `pyodbc` or `pymssql` for SQL Server connectivity
- Excellent for prototyping and data transformation

### Database Integration

All endpoints will call the existing `dbo.GetRuleByName` stored procedure:

```csharp
// C# Example using Dapper
using (var connection = new SqlConnection(connectionString))
{
    var parameters = new
    {
        RuleName = ruleName,
        LanguageKindName = languageKind
    };

    using (var multi = await connection.QueryMultipleAsync(
        "dbo.GetRuleByName",
        parameters,
        commandType: CommandType.StoredProcedure))
    {
        var ruleInfo = await multi.ReadFirstOrDefaultAsync<RuleInfo>();
        var composition = await multi.ReadAsync<RuleComposition>();
        var additionalIds = await multi.ReadAsync<AdditionalId>();
        var timeBlocks = await multi.ReadAsync<TimeBlock>();

        return new RuleResponse
        {
            RuleInfo = ruleInfo,
            Composition = composition.ToList(),
            AdditionalIds = additionalIds.ToList(),
            TimeBlocks = timeBlocks.ToList()
        };
    }
}
```

### Text File Generation

The PowerShell function `Export-RuleToTextFile.ps1` logic can be ported to C#:

```csharp
public class RuleTextExporter
{
    public string ExportToText(RuleResponse rule)
    {
        var sb = new StringBuilder();
        sb.AppendLine("=".PadRight(80, '='));
        sb.AppendLine("Rule Export from ATAPUtilities Database");
        sb.AppendLine($"Generated: {DateTime.UtcNow:yyyy-MM-dd HH:mm:ss}");
        sb.AppendLine("=".PadRight(80, '='));
        sb.AppendLine();

        sb.AppendLine("RULE INFORMATION");
        sb.AppendLine("-".PadRight(80, '-'));
        sb.AppendLine($"PhiloteID:            {rule.PhiloteId}");
        sb.AppendLine($"Rule Name:            {rule.RuleName}");
        // ... etc

        return sb.ToString();
    }
}
```

### Caching Strategy

Implement caching for frequently accessed Rules:

```csharp
[ResponseCache(Duration = 3600, VaryByQueryKeys = new[] { "languageKind" })]
public async Task<IActionResult> GetRule(string ruleName, string languageKind)
{
    // ... implementation
}
```

Or use distributed caching (Redis):

```csharp
var cacheKey = $"rule:{ruleName}:{languageKind}";
var cachedRule = await _cache.GetStringAsync(cacheKey);

if (cachedRule != null)
{
    return JsonSerializer.Deserialize<RuleResponse>(cachedRule);
}

// Fetch from database and cache
var rule = await _ruleService.GetRuleAsync(ruleName, languageKind);
await _cache.SetStringAsync(cacheKey, JsonSerializer.Serialize(rule),
    new DistributedCacheEntryOptions { AbsoluteExpirationRelativeToNow = TimeSpan.FromHours(1) });
```

### Rate Limiting

Implement rate limiting to prevent abuse:

```csharp
[RateLimit(Requests = 100, Period = "1m")]
public class RulesController : ControllerBase
{
    // ...
}
```

### API Versioning

Support multiple API versions:

```csharp
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/rules")]
public class RulesV1Controller : ControllerBase
{
    // v1 implementation
}

[ApiVersion("2.0")]
[Route("api/v{version:apiVersion}/rules")]
public class RulesV2Controller : ControllerBase
{
    // v2 implementation with breaking changes
}
```

---

## Security Considerations

1. **Authentication & Authorization**
   - Implement JWT-based authentication
   - Role-based access control (RBAC) for different user types
   - API key management for service-to-service communication

2. **Input Validation**
   - Sanitize all input parameters
   - Validate languageKind enum values
   - Limit page size to prevent DoS

3. **SQL Injection Prevention**
   - Use parameterized queries exclusively
   - Stored procedure already uses parameters

4. **Data Exposure**
   - Consider which fields should be publicly accessible
   - Implement field-level permissions if needed

---

## Testing

### Unit Tests

```csharp
[Fact]
public async Task GetRule_ReturnsRule_WhenRuleExists()
{
    // Arrange
    var mockService = new Mock<IRuleService>();
    mockService.Setup(s => s.GetRuleAsync("<cs-source-file>", "CSharp"))
               .ReturnsAsync(new RuleResponse { /* ... */ });

    var controller = new RulesController(mockService.Object);

    // Act
    var result = await controller.GetRule("<cs-source-file>", "CSharp");

    // Assert
    Assert.IsType<OkObjectResult>(result);
}
```

### Integration Tests

```csharp
[Fact]
public async Task GetRule_Integration_ReturnsActualRule()
{
    // Use test database or test container
    var client = _factory.CreateClient();
    var response = await client.GetAsync("/api/v1/rules/%3Ccs-source-file%3E?languageKind=CSharp");

    response.EnsureSuccessStatusCode();
    var content = await response.Content.ReadAsStringAsync();
    var rule = JsonSerializer.Deserialize<ApiResponse<RuleResponse>>(content);

    Assert.NotNull(rule.Data);
    Assert.Equal("<cs-source-file>", rule.Data.RuleName);
}
```

---

## Deployment

### Docker Container

```dockerfile
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 80
EXPOSE 443

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ["RuleExportApi/RuleExportApi.csproj", "RuleExportApi/"]
RUN dotnet restore "RuleExportApi/RuleExportApi.csproj"
COPY . .
WORKDIR "/src/RuleExportApi"
RUN dotnet build "RuleExportApi.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "RuleExportApi.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "RuleExportApi.dll"]
```

### Environment Variables

```bash
ASPNETCORE_ENVIRONMENT=Production
DATABASE_CONNECTION_STRING=Server=sqlserver;Database=ATAPUtilities;User Id=apiuser;Password=***;
JWT_SECRET_KEY=***
API_KEY_SALT=***
```

---

## API Documentation

Use Swagger/OpenAPI for automatic documentation:

```csharp
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "ATAP.Utilities Rule Export API",
        Version = "v1",
        Description = "API for exporting Rules from ATAPUtilities database"
    });

    // Include XML comments
    var xmlFile = $"{Assembly.GetExecutingAssembly().GetName().Name}.xml";
    var xmlPath = Path.Combine(AppContext.BaseDirectory, xmlFile);
    c.IncludeXmlComments(xmlPath);
});
```

Access at: `https://api.atap-utilities.example.com/swagger`

---

## Performance Optimization

1. **Database Indexes**

   ```sql
   CREATE NONCLUSTERED INDEX IX_Rule_Name_LanguageKind
   ON dbo.[Rule](Name, PrimitiveLanguageKindId)
   INCLUDE (PhiloteId, Purpose, SourceFileReference);
   ```

2. **Connection Pooling**
   - Enable SQL Server connection pooling
   - Configure appropriate pool size

3. **Async/Await**
   - Use async methods throughout the API
   - Prevent thread pool starvation

4. **Compression**
   ```csharp
   builder.Services.AddResponseCompression(options =>
   {
       options.EnableForHttps = true;
       options.Providers.Add<GzipCompressionProvider>();
   });
   ```

---

## Future Enhancements

1. **GraphQL Support** - Allow clients to query exactly what they need
2. **WebSocket Support** - Real-time Rule updates
3. **Bulk Operations** - Import/update Rules via API
4. **Rule Validation** - Validate Rule composition and syntax
5. **Rule Templates** - Generate Rules from templates
6. **Export Formats** - Add PDF, HTML, Word document exports
7. **Analytics** - Track Rule usage and popular Rules

---

## Version History

- **v1.0.0** (Proposed) - Initial API specification based on existing SQL stored procedures and PowerShell functions
