using System.Text.Json;
using System.Text.Json.Serialization;
using ATAP.Utilities.ETW;

namespace ATAP.Utilities.RRSBS.Contracts;

public static class RrsbsContractTypes
{
    public const string Rule = "rrsbs.rule";
}

public static class RrsbsSchemaVersions
{
    public const string V1_1_0 = "1.1.0";
    public const string Current = V1_1_0;
}

public sealed record RuleContractV1_1(
    Guid RuleId,
    string Name,
    string Language,
    string? Purpose,
    IReadOnlyList<RuleStepContractV1_1> Steps);

public sealed record RuleStepContractV1_1(
    int Sequence,
    string PrimitiveName,
    IReadOnlyDictionary<string, string?> Inputs);

public sealed record RrsbsPayloadEnvelope(
    string ContractType,
    string SchemaVersion,
    JsonElement Payload);

public sealed class RrsbsContractException : JsonException
{
    public RrsbsContractException(string message) : base(message) { }
}

public static class RrsbsContractSerializer
{
    public static string SerializeRule(RuleContractV1_1 payload)
    {
        ArgumentNullException.ThrowIfNull(payload);

        var payloadElement = JsonSerializer.SerializeToElement(
            payload,
            RrsbsJsonContext.Default.RuleContractV1_1);
        var envelope = new RrsbsPayloadEnvelope(
            RrsbsContractTypes.Rule,
            RrsbsSchemaVersions.Current,
            payloadElement);

        return JsonSerializer.Serialize(envelope, RrsbsJsonContext.Default.RrsbsPayloadEnvelope);
    }

    [ETWLog]
    public static RuleContractV1_1 DeserializeRule(string json)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(json);

        var envelope = JsonSerializer.Deserialize(json, RrsbsJsonContext.Default.RrsbsPayloadEnvelope)
            ?? throw new RrsbsContractException("The RRSBS payload envelope is null.");

        if (!string.Equals(envelope.ContractType, RrsbsContractTypes.Rule, StringComparison.Ordinal))
        {
            throw new RrsbsContractException($"Unsupported RRSBS contract type '{envelope.ContractType}'.");
        }

        if (!string.Equals(envelope.SchemaVersion, RrsbsSchemaVersions.Current, StringComparison.Ordinal))
        {
            throw new RrsbsContractException($"Unsupported RRSBS schema version '{envelope.SchemaVersion}'.");
        }

        return envelope.Payload.Deserialize(RrsbsJsonContext.Default.RuleContractV1_1)
            ?? throw new RrsbsContractException("The RRSBS rule payload is null.");
    }
}

[JsonSourceGenerationOptions(
    PropertyNamingPolicy = JsonKnownNamingPolicy.CamelCase,
    GenerationMode = JsonSourceGenerationMode.Metadata,
    RespectRequiredConstructorParameters = true,
    UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow)]
[JsonSerializable(typeof(RrsbsPayloadEnvelope))]
[JsonSerializable(typeof(RuleContractV1_1))]
[JsonSerializable(typeof(RuleStepContractV1_1))]
[JsonSerializable(typeof(Dictionary<string, string?>))]
public partial class RrsbsJsonContext : JsonSerializerContext;
