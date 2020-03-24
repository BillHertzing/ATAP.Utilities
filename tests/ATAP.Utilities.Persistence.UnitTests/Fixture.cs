


using ATAP.Utilities.Testing;
using FluentAssertions;
using Xunit;
using Xunit.Abstractions;


namespace ATAP.Utilities.Persistence.UnitTests
{
  public class PersistenceFixture : Fixture { }
  public partial class PersistenceUnitTests001 : IClassFixture<PersistenceFixture>
  {
    protected PersistenceFixture Fixture { get; }
    protected ITestOutputHelper TestOutput { get; }
    public PersistenceUnitTests001(ITestOutputHelper testOutput, PersistenceFixture fixture)
    {
      Fixture = fixture;
      TestOutput = testOutput;
    }
  }


}
