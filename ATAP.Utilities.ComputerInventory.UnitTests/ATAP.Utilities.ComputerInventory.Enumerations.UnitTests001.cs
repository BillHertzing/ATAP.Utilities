using System;
using System.Collections.Generic;
using System.Linq;
using System.Timers;
using FluentAssertions;
using Itenso.TimePeriod;
using ServiceStack.Text;
using static ServiceStack.Text.JsonSerializer;
using ServiceStack.Text.EnumMemberSerializer;
using Xunit;
using Xunit.Abstractions;
using ATAP.Utilities.ComputerInventory.Enumerations;
using ATAP.Utilities.ComputerInventory.Models;
using ATAP.Utilities.ComputerInventory.Extensions;

namespace ATAP.Utilities.ComputerInventory.Enumerations.UnitTests
{
  public class Fixture
  {
    // The correct answer to the test OperationEnumerationCountIsAsExpected
    public readonly int NumberOfGPUMakerEnumerations = 3;

    public Fixture() { }
  }

  public class ComputerInventoryEnumerationsUnitTests001 : IClassFixture<Fixture>
  {
    readonly ITestOutputHelper output;
    protected Fixture fixture;

    public ComputerInventoryEnumerationsUnitTests001(ITestOutputHelper output, Fixture fixture)
    {
      this.output = output;
      this.fixture = fixture;
    }
  }
}
