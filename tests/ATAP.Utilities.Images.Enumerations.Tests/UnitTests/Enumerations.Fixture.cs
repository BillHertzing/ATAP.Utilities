
using System;
using ATAP.Utilities.Testing;
using FluentAssertions;
using Xunit;
using Xunit.Abstractions;

namespace ATAP.Utilities.Images.Enumerations.UnitTests
{
  public class Fixture : DiFixture { }
  public partial class EnumerationsUnitTests001 : IClassFixture<Fixture>
  {
    protected Fixture Fixture { get; }
    protected ITestOutputHelper TestOutput { get; }

    public EnumerationsUnitTests001(ITestOutputHelper testOutput, Fixture fixture)
    {
      Fixture = fixture;
      TestOutput = testOutput;
    }
  }
}
