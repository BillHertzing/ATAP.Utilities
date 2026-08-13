using System.Text.Json;
using ATAP.Utilities.Testing;
using FluentAssertions;
using Xunit;
using Xunit.Abstractions;


namespace ATAP.Utilities.ComputerInventory.Hardware.Tests
{
  public sealed class Fixture : ConfigurableFixture
  {
    public HardwareTestSerializer Serializer { get; } = new();
  }

  public sealed class HardwareTestSerializer
  {
    public string Serialize(object value) => JsonSerializer.Serialize(value, value.GetType());

    public T? Deserialize<T>(string value) => JsonSerializer.Deserialize<T>(value);
  }
  public partial class ComputerInventoryHardwareUnitTests001 : IClassFixture<Fixture>
  {
    protected Fixture Fixture { get; }
    protected ITestOutputHelper TestOutput { get; }

    public ComputerInventoryHardwareUnitTests001(ITestOutputHelper testOutput, Fixture fixture)
    {
      Fixture = fixture;
      TestOutput = testOutput;
    }



  }
}
