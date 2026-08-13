using System;
using System.Linq;
using System.Reflection;
using System.Text.Json;
using ATAP.Utilities.DateTime.Interfaces;
using ATAP.Utilities.DateTime.Model;
using FluentAssertions;
using Xunit;

namespace ATAP.Utilities.DateTime.Tests;

[Trait("Category", "Unit")]
public sealed class DateTimeSerializationUnitTests
{
  private const string StartJson = "\"2026-08-08T12:34:56.1234567Z\"";
  private const string EndJson = "\"2026-08-08T13:34:56.1234567Z\"";

  [Fact]
  public void UtcInstant_RoundTrip_WritesCanonicalUtcString()
  {
    var value = JsonSerializer.Deserialize<UtcInstant>(StartJson);

    JsonSerializer.Serialize(value).Should().Be(StartJson);
    value.Value.Ticks.Should().Be(new DateTimeOffset(2026, 8, 8, 12, 34, 56, TimeSpan.Zero).AddTicks(1_234_567).Ticks);
  }

  [Theory]
  [InlineData("\"2026-08-08T12:34:56.1234567+00:00\"")]
  [InlineData("\"2026-08-08T12:34:56.1234567-00:00\"")]
  public void UtcInstant_ExplicitZeroOffset_IsAcceptedAndCanonicalized(string json)
  {
    var value = JsonSerializer.Deserialize<UtcInstant>(json);

    JsonSerializer.Serialize(value).Should().Be(StartJson);
  }

  [Theory]
  [InlineData("null")]
  [InlineData("0")]
  [InlineData("\"2026-08-08T12:34:56.1234567\"")]
  [InlineData("\"2026-08-08T12:34:56.1234567+01:00\"")]
  [InlineData("\"2026-08-08T12:34:56.123456Z\"")]
  [InlineData("\"2026-08-08T12:34:56.12345678Z\"")]
  [InlineData("\"2026-08-08t12:34:56.1234567Z\"")]
  public void UtcInstant_InvalidWireForms_ThrowJsonException(string json) =>
    FluentActions.Invoking(() => JsonSerializer.Deserialize<UtcInstant>(json))
      .Should().Throw<JsonException>();

  [Fact]
  public void TemporalDuration_RoundTrip_WritesExactTicksObject()
  {
    const string json = "{\"ticks\":1234567}";

    var value = JsonSerializer.Deserialize<TemporalDuration>(json);

    value.Ticks.Should().Be(1_234_567);
    JsonSerializer.Serialize(value).Should().Be(json);
  }

  [Theory]
  [InlineData("null")]
  [InlineData("\"PT1S\"")]
  [InlineData("{}")]
  [InlineData("{\"ticks\":-1}")]
  [InlineData("{\"ticks\":1.0}")]
  [InlineData("{\"Ticks\":1}")]
  [InlineData("{\"ticks\":1,\"ticks\":1}")]
  [InlineData("{\"ticks\":1,\"durationDescription\":\"1 tick\"}")]
  public void TemporalDuration_InvalidWireForms_ThrowJsonException(string json) =>
    FluentActions.Invoking(() => JsonSerializer.Deserialize<TemporalDuration>(json))
      .Should().Throw<JsonException>();

  [Fact]
  public void TemporalValidityPeriod_RoundTrip_WritesOnlyRatifiedProperties()
  {
    var json = $"{{\"validFromUtc\":{StartJson},\"validToUtc\":{EndJson}}}";

    var value = JsonSerializer.Deserialize<TemporalValidityPeriod>(json);

    value.Should().NotBeNull();
    value!.IsOpenEnded.Should().BeFalse();
    JsonSerializer.Serialize(value).Should().Be(json);
  }

  [Fact]
  public void TemporalValidityPeriod_OpenEnd_RoundTripWritesNull()
  {
    var json = $"{{\"validFromUtc\":{StartJson},\"validToUtc\":null}}";

    var value = JsonSerializer.Deserialize<TemporalValidityPeriod>(json);

    value.Should().NotBeNull();
    value!.IsOpenEnded.Should().BeTrue();
    JsonSerializer.Serialize(value).Should().Be(json);
  }

  [Theory]
  [InlineData("null")]
  [InlineData("{}")]
  [InlineData("{\"validFromUtc\":\"2026-08-08T12:34:56.1234567Z\"}")]
  [InlineData("{\"validToUtc\":null}")]
  [InlineData("{\"validFromUtc\":null,\"validToUtc\":null}")]
  [InlineData("{\"validFromUtc\":\"2026-08-08T12:34:56.1234567Z\",\"validToUtc\":\"2026-08-08T12:34:56.1234567Z\"}")]
  [InlineData("{\"validFromUtc\":\"2026-08-08T13:34:56.1234567Z\",\"validToUtc\":\"2026-08-08T12:34:56.1234567Z\"}")]
  [InlineData("{\"validFromUtc\":\"2026-08-08T12:34:56.1234567Z\",\"validToUtc\":null,\"duration\":null}")]
  [InlineData("{\"ValidFromUtc\":\"2026-08-08T12:34:56.1234567Z\",\"validToUtc\":null}")]
  public void TemporalValidityPeriod_InvalidWireForms_ThrowJsonException(string json) =>
    FluentActions.Invoking(() => JsonSerializer.Deserialize<TemporalValidityPeriod>(json))
      .Should().Throw<JsonException>();

  [Fact]
  public void TemporalValidityPeriodSet_RoundTrip_WritesExactArray()
  {
    var json = $"[{{\"validFromUtc\":{StartJson},\"validToUtc\":{EndJson}}},{{\"validFromUtc\":{EndJson},\"validToUtc\":null}}]";

    var value = JsonSerializer.Deserialize<TemporalValidityPeriodSet>(json);

    value.Should().NotBeNull();
    value!.Count.Should().Be(2);
    JsonSerializer.Serialize(value).Should().Be(json);
  }

  [Fact]
  public void TemporalValidityPeriodSet_EmptyArray_RoundTripsAsEmptySet()
  {
    var value = JsonSerializer.Deserialize<TemporalValidityPeriodSet>("[]");

    value.Should().Equal(TemporalValidityPeriodSet.Empty);
    JsonSerializer.Serialize(value).Should().Be("[]");
  }

  [Theory]
  [InlineData("null")]
  [InlineData("{}")]
  [InlineData("[null]")]
  [InlineData("[{\"validFromUtc\":\"2026-08-08T12:34:56.1234567Z\",\"validToUtc\":null},{\"validFromUtc\":\"2026-08-08T13:34:56.1234567Z\",\"validToUtc\":null}]")]
  [InlineData("[{\"validFromUtc\":\"2026-08-08T12:34:56.1234567Z\",\"validToUtc\":\"2026-08-08T14:34:56.1234567Z\"},{\"validFromUtc\":\"2026-08-08T13:34:56.1234567Z\",\"validToUtc\":null}]")]
  public void TemporalValidityPeriodSet_InvalidWireForms_ThrowJsonException(string json) =>
    FluentActions.Invoking(() => JsonSerializer.Deserialize<TemporalValidityPeriodSet>(json))
      .Should().Throw<JsonException>();

  [Fact]
  public void TemporalTypes_PublicSurface_ContainsNoConverterOrItensoType()
  {
    var publicTypes = new[]
      {
        typeof(UtcInstant),
        typeof(TemporalDuration),
        typeof(TemporalValidityPeriod),
        typeof(TemporalValidityPeriodSet),
      }
      .SelectMany(type => type.Assembly.GetExportedTypes())
      .Distinct()
      .ToArray();
    var publicMemberSignatures = publicTypes
      .SelectMany(type => type.GetMembers(BindingFlags.Public | BindingFlags.Instance | BindingFlags.Static))
      .Select(member => member.ToString())
      .Where(signature => signature is not null)
      .ToArray();

    publicTypes.Should().NotContain(type => type.Name.Contains("JsonConverter", StringComparison.Ordinal));
    publicMemberSignatures.Should().NotContain(signature =>
      signature!.Contains("Itenso.TimePeriod.", StringComparison.Ordinal));
  }
}
