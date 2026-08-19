using System;
using System.Linq;
using ServiceStack.OrmLite.SqlServer;
using Xunit;

namespace ATAP.Utilities.Persistence.Tests;

public sealed class SqlServerDataProviderTests
{
  [Fact]
  public void SqlServerDialectProvider_UsesMicrosoftDataSqlClient()
  {
    var referencedAssemblies = typeof(SqlServerDialect).Assembly.GetReferencedAssemblies()
      .Select(assemblyName => assemblyName.Name)
      .ToArray();

    Assert.Contains("Microsoft.Data.SqlClient", referencedAssemblies, StringComparer.Ordinal);
    Assert.DoesNotContain("System.Data.SqlClient", referencedAssemblies, StringComparer.Ordinal);
    Assert.NotNull(SqlServerDialect.Provider);
  }
}