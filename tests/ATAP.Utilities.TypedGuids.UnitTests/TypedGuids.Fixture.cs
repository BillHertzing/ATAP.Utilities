
using System;
using ATAP.Utilities.Testing;
using FluentAssertions;
using Xunit;
using Xunit.Abstractions;
using Microsoft.Extensions.DependencyInjection;
using System.Linq;
using System.Reflection;


namespace ATAP.Utilities.TypedGuids.UnitTests {
  public class TypedGuidsFixture : DiFixture { }
  public partial class IntGuidUnitTests001 : IClassFixture<TypedGuidsFixture> {
    protected TypedGuidsFixture Fixture { get; }
    protected ITestOutputHelper TestOutput { get; }

    public IntGuidUnitTests001(ITestOutputHelper testOutput, TypedGuidsFixture fixture) {
      Fixture = fixture;
      TestOutput = testOutput;
    }

  }
}
