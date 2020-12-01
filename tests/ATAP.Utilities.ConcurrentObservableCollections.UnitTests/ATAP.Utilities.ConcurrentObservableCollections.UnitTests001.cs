using System;
using Xunit;
using Xunit.Abstractions;
using FluentAssertions;
using ATAP.Utilities.ConcurrentObservableCollections;

namespace ATAP.Utilities.ConcurrentObservableCollections.UnitTests
{
  public class Fixture
  {

    public Fixture()
    {
    }
  }

  public class ConcurrentObservableCollectionsUnitTests001 : IClassFixture<Fixture>
  {
    readonly ITestOutputHelper output;
    protected Fixture fixture;

    public ConcurrentObservableCollectionsUnitTests001(ITestOutputHelper output, Fixture fixture)
    {
      this.output = output;
      this.fixture = fixture;
    }
  }
}
