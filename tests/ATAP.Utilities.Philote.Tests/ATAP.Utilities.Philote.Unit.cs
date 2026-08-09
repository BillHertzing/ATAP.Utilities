using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using ATAP.Utilities.DateTime.Interfaces;
using ATAP.Utilities.DateTime.Model;
using FluentAssertions;
using Xunit;

namespace ATAP.Utilities.Philote.Tests;

public sealed class PhiloteUnitTests : IClassFixture<Fixture>
{
  private static readonly Guid IdValue = new("01234567-abcd-9876-cdef-456789abcdef");
  private readonly Fixture _fixture;

  public PhiloteUnitTests(Fixture fixture)
  {
    _fixture = fixture;
  }

  [Theory]
  [MemberData(nameof(PhiloteTestData.ValidPeriodCollections), MemberType = typeof(PhiloteTestData))]
  public void Constructor_ValidCollections_PublishesCanonicalImmutableState(
    IEnumerable<TemporalValidityPeriod> periods)
  {
    // Arrange
    var id = new TestGuidId(IdValue);

    // Act
    var philote = new GuidPhilote<TestGuidId>(id, null, periods);

    // Assert
    philote.Id.Should().Be(id);
    philote.AdditionalIds.Should().BeEmpty();
    philote.ValidityPeriods.Should().BeInAscendingOrder(period => period.ValidFromUtc);
  }

  [Fact]
  public void Constructor_NullCollections_NormalizesToEmpty()
  {
    // Arrange / Act
    var philote = new GuidPhilote<TestGuidId>(new TestGuidId(IdValue), null, null);

    // Assert
    philote.AdditionalIds.Should().BeEmpty();
    philote.ValidityPeriods.Should().BeEmpty();
  }

  [Fact]
  public void Constructor_OverlappingPeriods_RejectsCollection()
  {
    // Arrange
    var periods = new[]
    {
      new TemporalValidityPeriod(PhiloteTestData.First, PhiloteTestData.Third),
      new TemporalValidityPeriod(PhiloteTestData.Second, PhiloteTestData.Fourth)
    };

    // Act
    var action = () => new GuidPhilote<TestGuidId>(new TestGuidId(IdValue), null, periods);

    // Assert
    action.Should().Throw<ArgumentException>().Which.ParamName.Should().Be("periods");
  }

  [Fact]
  public void IsValidAt_BoundedAndOpenPeriods_UsesHalfOpenBoundaries()
  {
    // Arrange
    var philote = new GuidPhilote<TestGuidId>(
      new TestGuidId(IdValue),
      null,
      new[]
      {
        new TemporalValidityPeriod(PhiloteTestData.First, PhiloteTestData.Second),
        new TemporalValidityPeriod(PhiloteTestData.Third, null)
      });

    // Act / Assert
    philote.IsValidAt(PhiloteTestData.First).Should().BeTrue();
    philote.IsValidAt(PhiloteTestData.Second).Should().BeFalse();
    philote.IsValidAt(PhiloteTestData.Third).Should().BeTrue();
    philote.IsValidAt(PhiloteTestData.Fourth).Should().BeTrue();
  }

  [Fact]
  public void Equality_SameRuntimeTypeAndId_IgnoresAssociatedState()
  {
    // Arrange
    var id = new TestGuidId(IdValue);
    var empty = new GuidPhilote<TestGuidId>(id, null, null);
    var active = new GuidPhilote<TestGuidId>(
      new TestGuidId(IdValue),
      new Dictionary<string, ATAP.Utilities.StronglyTypedId.IAbstractStronglyTypedId<Guid>>
      {
        ["secondary"] = new TestGuidId(Guid.NewGuid())
      },
      new[] { new TemporalValidityPeriod(PhiloteTestData.First, null) });

    // Act / Assert
    empty.Should().Be(active);
    empty.GetHashCode().Should().Be(active.GetHashCode());
  }

  [Fact]
  public void ActivateAndDeactivate_ReturnNewInstancesAndPreserveReceiver()
  {
    // Arrange
    var original = new GuidPhilote<TestGuidId>(new TestGuidId(IdValue), null, null);

    // Act
    var active = original.Activate(PhiloteTestData.First);
    var inactive = active.Deactivate(PhiloteTestData.Second);

    // Assert
    original.ValidityPeriods.Should().BeEmpty();
    active.ValidityPeriods.Should().ContainSingle().Which.ValidToUtc.Should().BeNull();
    inactive.ValidityPeriods.Should().ContainSingle().Which.ValidToUtc.Should().Be(PhiloteTestData.Second);
  }

  [Fact]
  public void Json_RoundTrip_PreservesCanonicalState()
  {
    // Arrange
    var philote = new GuidPhilote<TestGuidId>(
      new TestGuidId(IdValue),
      new Dictionary<string, ATAP.Utilities.StronglyTypedId.IAbstractStronglyTypedId<Guid>>
      {
        ["secondary"] = new TestGuidId(new Guid("11111111-2222-3333-4444-555555555555"))
      },
      new[]
      {
        new TemporalValidityPeriod(PhiloteTestData.First, PhiloteTestData.Second),
        new TemporalValidityPeriod(PhiloteTestData.Third, null)
      });

    // Act
    var json = JsonSerializer.Serialize(philote, _fixture.SerializerOptions);
    var roundTripped = JsonSerializer.Deserialize<GuidPhilote<TestGuidId>>(json, _fixture.SerializerOptions);

    // Assert
    json.Should().Be("{\"id\":\"01234567-abcd-9876-cdef-456789abcdef\",\"additionalIds\":{\"secondary\":\"11111111-2222-3333-4444-555555555555\"},\"validityPeriods\":[{\"validFromUtc\":\"2026-08-08T00:00:00.0000000Z\",\"validToUtc\":\"2026-08-09T00:00:00.0000000Z\"},{\"validFromUtc\":\"2026-08-10T00:00:00.0000000Z\",\"validToUtc\":null}]}");
    roundTripped.Should().NotBeNull();
    roundTripped!.Id.Should().Be(philote.Id);
    roundTripped.AdditionalIds.Should().BeEquivalentTo(philote.AdditionalIds);
    roundTripped.ValidityPeriods.Should().Equal(philote.ValidityPeriods);
  }

  [Theory]
  [InlineData("{\"id\":\"01234567-abcd-9876-cdef-456789abcdef\",\"TimeBlocks\":[]}")]
  [InlineData("{\"id\":\"01234567-abcd-9876-cdef-456789abcdef\",\"timeBlocks\":[]}")]
  [InlineData("{\"id\":\"01234567-abcd-9876-cdef-456789abcdef\",\"validityPeriods\":[{\"Start\":\"2026-08-08T00:00:00Z\"}]}")]
  public void Json_LegacyTemporalShape_ThrowsJsonException(string json)
  {
    // Arrange / Act
    var action = () => JsonSerializer.Deserialize<GuidPhilote<TestGuidId>>(json, _fixture.SerializerOptions);

    // Assert
    action.Should().Throw<JsonException>();
  }

  [Fact]
  public void Json_NonUtcBoundary_ThrowsJsonException()
  {
    // Arrange
    const string json = "{\"id\":\"01234567-abcd-9876-cdef-456789abcdef\",\"validityPeriods\":[{\"validFromUtc\":\"2026-08-08T01:00:00.0000000+01:00\",\"validToUtc\":null}]}";

    // Act
    var action = () => JsonSerializer.Deserialize<GuidPhilote<TestGuidId>>(json, _fixture.SerializerOptions);

    // Assert
    action.Should().Throw<JsonException>();
  }

  [Fact]
  public void PublicPhiloteSurface_ContainsNoItensoOrTimeBlocks()
  {
    // Arrange
    var types = new[]
    {
      typeof(IAbstractPhilote<,>),
      typeof(AbstractPhilote<,>),
      typeof(GuidPhilote<>),
      typeof(IntPhilote<>)
    };

    // Act
    var signatures = types
      .SelectMany(type => type.GetMembers())
      .Select(member => member.ToString())
      .Where(signature => signature is not null)
      .ToArray();

    // Assert
    signatures.Should().NotContain(signature => signature!.Contains("Itenso", StringComparison.Ordinal));
    signatures.Should().NotContain(signature => signature!.Contains("TimeBlocks", StringComparison.Ordinal));
  }

  [Fact]
  public void PhiloteInterfaces_DependsOnDateTimeInterfacesButNotDateTimeModel()
  {
    // Arrange
    var philoteInterfaceType = typeof(IAbstractPhilote<,>);

    // Act
    var validityPeriodsProperty = philoteInterfaceType.GetProperty(nameof(IAbstractPhilote<TestGuidId, Guid>.ValidityPeriods));
    var references = philoteInterfaceType.Assembly
      .GetReferencedAssemblies()
      .Select(reference => reference.Name)
      .ToArray();

    // Assert
    validityPeriodsProperty.Should().NotBeNull();
    validityPeriodsProperty!.PropertyType.Should().Be(typeof(IReadOnlyList<ITemporalValidityPeriod>));
    references.Should().Contain("ATAP.Utilities.DateTime.Interfaces");
    references.Should().NotContain("ATAP.Utilities.DateTime.Model");
  }
}
