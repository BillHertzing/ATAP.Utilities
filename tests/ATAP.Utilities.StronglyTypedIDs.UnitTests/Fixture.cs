
using System;
using ATAP.Utilities.Testing;
using FluentAssertions;
using Xunit;
using Xunit.Abstractions;
using Microsoft.Extensions.DependencyInjection;
using System.Linq;
using System.Reflection;


namespace ATAP.Utilities.StronglyTypedIDs.UnitTests {
  public class Fixture : DiFixture { }
  public partial class IntGuidUnitTests001 : IClassFixture<Fixture> {
    protected Fixture Fixture { get; }
    protected ITestOutputHelper TestOutput { get; }

    public IntGuidUnitTests001(ITestOutputHelper testOutput, Fixture fixture) {
      Fixture = fixture;
      TestOutput = testOutput;
    }

  }
}
