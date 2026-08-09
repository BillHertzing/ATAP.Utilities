using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using ATAP.Utilities.DateTime.Interfaces;
using FluentAssertions;
using Xunit;

namespace ATAP.Utilities.DateTime.Tests;

[Trait("Category", "Unit")]
public sealed class DateTimeInterfacesUnitTests
{
  [Fact]
  public void IHalfOpenTemporalPeriod_HasRatifiedPublicSurface()
  {
    // Arrange
    var nullabilityContext = new NullabilityInfoContext();
    var periodType = typeof(IHalfOpenTemporalPeriod);

    // Act
    var properties = periodType.GetProperties(BindingFlags.Instance | BindingFlags.Public);
    var contains = periodType.GetMethod(nameof(IHalfOpenTemporalPeriod.Contains));

    // Assert
    periodType.IsInterface.Should().BeTrue();
    properties.Should().ContainSingle(property => property.Name == nameof(IHalfOpenTemporalPeriod.ValidFromUtc)
      && property.PropertyType == typeof(UtcInstant));
    properties.Should().ContainSingle(property => property.Name == nameof(IHalfOpenTemporalPeriod.ValidToUtc)
      && property.PropertyType == typeof(UtcInstant?));
    properties.Should().ContainSingle(property => property.Name == nameof(IHalfOpenTemporalPeriod.IsOpenEnded)
      && property.PropertyType == typeof(bool));
    properties.Should().ContainSingle(property => property.Name == nameof(IHalfOpenTemporalPeriod.Duration)
      && property.PropertyType == typeof(TemporalDuration?));
    contains.Should().NotBeNull();
    contains!.ReturnType.Should().Be(typeof(bool));
    contains.GetParameters().Should().ContainSingle();
    contains.GetParameters()[0].ParameterType.Should().Be(typeof(UtcInstant));
  }

  [Fact]
  public void ITemporalPeriodCalculator_HasRatifiedPublicSurface()
  {
    // Arrange
    var nullabilityContext = new NullabilityInfoContext();
    var calculatorType = typeof(ITemporalPeriodCalculator);

    // Act
    var contains = calculatorType.GetMethod(nameof(ITemporalPeriodCalculator.Contains));
    var overlaps = calculatorType.GetMethod(nameof(ITemporalPeriodCalculator.Overlaps));
    var intersections = Enumerable
      .Where(
        calculatorType.GetMethods(),
        method => method.Name == nameof(ITemporalPeriodCalculator.GetBoundedIntersection))
      .OrderBy(method => method.GetParameters().Length)
      .ToArray();
    var gaps = calculatorType.GetMethod(nameof(ITemporalPeriodCalculator.GetInternalGaps));

    // Assert
    calculatorType.IsInterface.Should().BeTrue();
    contains.Should().NotBeNull();
    contains!.ReturnType.Should().Be(typeof(bool));
    contains.GetParameters().Select(parameter => parameter.ParameterType)
      .Should().Equal(typeof(IHalfOpenTemporalPeriod), typeof(UtcInstant));
    overlaps.Should().NotBeNull();
    overlaps!.ReturnType.Should().Be(typeof(bool));
    overlaps.GetParameters().Select(parameter => parameter.ParameterType)
      .Should().Equal(typeof(IHalfOpenTemporalPeriod), typeof(IHalfOpenTemporalPeriod));
    intersections.Should().HaveCount(2);
    intersections[0].ReturnType.Should().Be(typeof(IHalfOpenTemporalPeriod));
    nullabilityContext.Create(intersections[0].ReturnParameter).ReadState.Should().Be(NullabilityState.Nullable);
    intersections[0].GetParameters().Select(parameter => parameter.ParameterType)
      .Should().Equal(typeof(IHalfOpenTemporalPeriod), typeof(IHalfOpenTemporalPeriod));
    intersections[1].ReturnType.Should().Be(typeof(IHalfOpenTemporalPeriod));
    nullabilityContext.Create(intersections[1].ReturnParameter).ReadState.Should().Be(NullabilityState.Nullable);
    intersections[1].GetParameters().Select(parameter => parameter.ParameterType)
      .Should().Equal(typeof(IHalfOpenTemporalPeriod), typeof(IHalfOpenTemporalPeriod), typeof(UtcInstant));
    gaps.Should().NotBeNull();
    gaps!.ReturnType.Should().Be(typeof(IReadOnlyList<IHalfOpenTemporalPeriod>));
    gaps.GetParameters().Should().ContainSingle();
    gaps.GetParameters()[0].ParameterType.Should().Be(typeof(IReadOnlyList<IHalfOpenTemporalPeriod>));
  }

  [Fact]
  public void Interfaces_PublicSurfaceAndAssemblyReferences_ContainNoItensoTypes()
  {
    // Arrange
    var publicMembers = new[] { typeof(IHalfOpenTemporalPeriod), typeof(ITemporalPeriodCalculator) }
      .SelectMany(type => type.GetMembers(BindingFlags.Instance | BindingFlags.Public))
      .Select(member => member.ToString());
    var referencedAssemblies = typeof(IHalfOpenTemporalPeriod).Assembly.GetReferencedAssemblies();

    // Act
    var memberSignatures = publicMembers.ToArray();
    var referenceNames = referencedAssemblies.Select(assemblyName => assemblyName.FullName).ToArray();

    // Assert
    memberSignatures.Should().NotContain(signature => signature!.Contains("Itenso", StringComparison.Ordinal));
    referenceNames.Should().NotContain(reference => reference!.Contains("Itenso", StringComparison.Ordinal));
  }
}
