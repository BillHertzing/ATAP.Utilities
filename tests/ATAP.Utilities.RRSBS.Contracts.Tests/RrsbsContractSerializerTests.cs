using System.Text.Json;
using ATAP.Utilities.RRSBS.Contracts;
using ATAP.Utilities.RRSBS.Domain;
using ATAP.Utilities.RRSBS.Persistence;

namespace ATAP.Utilities.RRSBS.Contracts.Tests;

public sealed class RrsbsContractSerializerTests
{
    private static readonly Guid RuleId = Guid.Parse("e5ac7fba-a554-41cc-9b1c-96aba88d801b");

    [Fact]
    public void SerializeAndDeserializeRule_SchemaOneOne_RoundTrips()
    {
        var original = CreateContract();

        var json = RrsbsContractSerializer.SerializeRule(original);
        var restored = RrsbsContractSerializer.DeserializeRule(json);

        Assert.Equal(original.RuleId, restored.RuleId);
        Assert.Equal(original.Name, restored.Name);
        Assert.Equal(original.Language, restored.Language);
        Assert.Equal(original.Purpose, restored.Purpose);
        Assert.Equal(original.Steps[0].Sequence, restored.Steps[0].Sequence);
        Assert.Equal(original.Steps[0].PrimitiveName, restored.Steps[0].PrimitiveName);
        Assert.Equal(original.Steps[0].Inputs, restored.Steps[0].Inputs);
        Assert.Contains("\"contractType\":\"rrsbs.rule\"", json, StringComparison.Ordinal);
        Assert.Contains("\"schemaVersion\":\"1.1.0\"", json, StringComparison.Ordinal);
    }

    [Theory]
    [InlineData("rrsbs.unknown", "1.1.0")]
    [InlineData("rrsbs.rule", "2.0.0")]
    public void DeserializeRule_UnsupportedEnvelope_Rejects(string contractType, string schemaVersion)
    {
        var fixture = $$$"""
            {"contractType":"{{{contractType}}}","schemaVersion":"{{{schemaVersion}}}","payload":{"ruleId":"{{{RuleId}}}","name":"compile","language":"CSharp","purpose":null,"steps":[]}}
            """;

        var exception = Assert.Throws<RrsbsContractException>(
            () => RrsbsContractSerializer.DeserializeRule(fixture));

        Assert.Contains("Unsupported RRSBS", exception.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void DeserializeRule_KnownOneOneFixture_RemainsCompatible()
    {
        var fixture = $$$"""
            {"contractType":"rrsbs.rule","schemaVersion":"1.1.0","payload":{"ruleId":"{{{RuleId}}}","name":"compile","language":"CSharp","purpose":"Build a project","steps":[{"sequence":1,"primitiveName":"dotnet-build","inputs":{"configuration":"Release"}}]}}
            """;

        var result = RrsbsContractSerializer.DeserializeRule(fixture);

        Assert.Equal(RuleId, result.RuleId);
        Assert.Equal("Release", result.Steps[0].Inputs["configuration"]);
    }

    [Theory]
    [InlineData("{\"contractType\":\"rrsbs.rule\",\"schemaVersion\":\"1.1.0\",\"payload\":{\"ruleId\":\"e5ac7fba-a554-41cc-9b1c-96aba88d801b\",\"language\":\"CSharp\",\"purpose\":null,\"steps\":[]}}")]
    [InlineData("{\"contractType\":\"rrsbs.rule\",\"schemaVersion\":\"1.1.0\",\"payload\":{\"ruleId\":\"e5ac7fba-a554-41cc-9b1c-96aba88d801b\",\"name\":\"compile\",\"language\":\"CSharp\",\"purpose\":null,\"steps\":[],\"unexpected\":true}}")]
    public void DeserializeRule_InvalidPayloadShape_Rejects(string fixture)
    {
        Assert.Throws<JsonException>(() => RrsbsContractSerializer.DeserializeRule(fixture));
    }

    [Fact]
    public void Assemblies_KeepPersistenceContractAndDomainModelsDistinct()
    {
        Assert.NotEqual(typeof(RuleRecord).Assembly, typeof(RuleContractV1_1).Assembly);
        Assert.NotEqual(typeof(RuleRecord).Assembly, typeof(RuleDefinition).Assembly);
        Assert.NotEqual(typeof(RuleContractV1_1).Assembly, typeof(RuleDefinition).Assembly);
    }

    private static RuleContractV1_1 CreateContract() => new(
        RuleId,
        "compile",
        "CSharp",
        "Build a project",
        [new RuleStepContractV1_1(1, "dotnet-build", new Dictionary<string, string?> { ["configuration"] = "Release" })]);
}
