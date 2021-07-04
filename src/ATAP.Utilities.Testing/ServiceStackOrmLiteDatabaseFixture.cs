using System;


using ServiceStack.OrmLite;

namespace ATAP.Utilities.Testing {

  /// <summary>
  /// A Test Fixture Interface that adds support for ServiceStack OrmLite Databases
  /// </summary>
  public interface IServiceStackOrmLiteDatabaseFixture {
    public IOrmLiteDialectProvider Provider { get; set; }
  }
  /// <summary>
  /// A Test Fixture that adds support for ServiceStack OrmLite Databases
  /// </summary>
  public partial class ServiceStackOrmLiteDatabaseFixture : DatabaseFixture, IServiceStackOrmLiteDatabaseFixture {
    public IOrmLiteDialectProvider Provider { get; set; }
    public ServiceStackOrmLiteDatabaseFixture() : base() {
    }
    public void Configure(IOrmLiteDialectProvider provider) {
      Provider = provider ?? throw new ArgumentNullException(nameof(provider));
    }
  }
}
