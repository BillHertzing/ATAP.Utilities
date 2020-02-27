using System;
using System.Collections.Generic;
using System.Linq;
using System.Timers;
using FluentAssertions;
using Xunit;
using Xunit.Abstractions;
using ServiceStack.Text;
using ATAP.Utilities.ComputerInventory.Enumerations;
using ATAP.Utilities.ComputerInventory.Extensions;
using ATAP.Utilities.ComputerInventory.Configuration;
using Itenso.TimePeriod;
using ATAP.Utilities.ComputerInventory.Configuration.ProcessInfo;
using ATAP.Utilities.ComputerInventory.Configuration.Hardware;
using ATAP.Utilities.ComputerInventory.Configuration.Software;
using ATAP.Utilities.ComputerInventory.Interfaces.Software;

namespace ATAP.Utilities.ComputerInventory.Configuration.UnitTests
{
  public class ModelsSoftwareUnitTests001 : IClassFixture<Fixture>
  {
    protected Fixture Fixture { get; }
    protected ITestOutputHelper TestOutput { get; }

    public ModelsSoftwareUnitTests001(ITestOutputHelper testOutput, Fixture fixture)
    {
      Fixture = fixture;
      TestOutput = testOutput;
    }

    [Theory]
    [MemberData(nameof(ComputerSoftwareProgramTestDataGenerator.ComputerSoftwareProgramTestData), MemberType = typeof(ComputerSoftwareProgramTestDataGenerator))]
    public void ComputerSoftwareProgramDeserialize(ComputerSoftwareProgramTestData inComputerSoftwareProgramTestData)
    {
      JsonSerializer.DeserializeFromString<ComputerSoftwareProgram>(inComputerSoftwareProgramTestData.SerializedComputerSoftwareProgram).Should().Be(inComputerSoftwareProgramTestData.ComputerSoftwareProgram);
    }

    [Theory]
    [MemberData(nameof(ComputerSoftwareProgramTestDataGenerator.ComputerSoftwareProgramTestData), MemberType = typeof(ComputerSoftwareProgramTestDataGenerator))]
    public void ComputerSoftwareProgramSerialize(ComputerSoftwareProgramTestData inComputerSoftwareProgramTestData)
    {
      JsonSerializer.SerializeToString<ComputerSoftwareProgram>(inComputerSoftwareProgramTestData.ComputerSoftwareProgram).Should().Be(inComputerSoftwareProgramTestData.SerializedComputerSoftwareProgram);
    }

  }
}
