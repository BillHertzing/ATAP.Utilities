using System;
using System.Data;
using TestingExtensions = ATAP.Utilities.Testing.Extensions;

namespace ATAP.Utilities.Testing {

  /// <summary>
  /// A Test Fixture Interface that adds support for Databases
  /// </summary>
  public interface IDatabaseFixture {
    public string ConnectionString { get; set; }
    public string DatabaseName { get; set; }
    public IDbConnection Db { get; set; }
  }

  /// <summary>
  /// A Test Fixture that adds support for Databases
  /// </summary>
  public class DatabaseFixture : ConfigurableFixture, IDatabaseFixture {

    public string ConnectionString { get; set; }
    public string DatabaseName { get; set; }
    public IDbConnection Db { get; set; }

    public DatabaseFixture() : base() {
    }

    public void Configure(string connectionString, string databaseName, IDbConnection db) {
      ConnectionString = connectionString ?? throw new ArgumentNullException(nameof(connectionString));
      DatabaseName = databaseName ?? throw new ArgumentNullException(nameof(databaseName));
      Db = db ?? throw new ArgumentNullException(nameof(db));
    }
  }
}
