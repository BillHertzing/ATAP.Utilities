using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using ATAP.Utilities.DateTime.Interfaces;
using ATAP.Utilities.DateTime.Model;
using FluentAssertions;
using Xunit;

namespace ATAP.Utilities.DateTime.Tests;

[Trait("Category", "Unit")]
public sealed class TemporalValidityPeriodSetUnitTests
{
  [Fact]
  public void Constructor_NullEnumerable_CreatesEmptyValidSet()
  {
    // Arrange
    IEnumerable<TemporalValidityPeriod>? periods = null;

    // Act
    var result = new TemporalValidityPeriodSet(periods);

    // Assert
    result.Should().BeEmpty();
    result.Equals(TemporalValidityPeriodSet.Empty).Should().BeTrue();
  }

  [Fact]
  public void Constructor_UnsortedSinglePassSource_MaterializesOnceSortsAndDoesNotRetainSource()
  {
    // Arrange
    var source = new List<TemporalValidityPeriod>
    {
      Period(20, 30),
      Period(0, 10),
      Period(10, 15),
    };
    var singlePassSource = new SinglePassEnumerable(source);

    // Act
    var result = new TemporalValidityPeriodSet(singlePassSource);
    source.Clear();

    // Assert
    singlePassSource.EnumerationCount.Should().Be(1);
    result.Should().Equal(Period(0, 10), Period(10, 15), Period(20, 30));
  }

  [Fact]
  public void Constructor_InterfaceImplementation_MaterializesValidatedConcreteSnapshot()
  {
    // Arrange
    ITemporalValidityPeriod source = new TestTemporalValidityPeriod(Instant(10), Instant(20));

    // Act
    var result = new TemporalValidityPeriodSet(new[] { source });

    // Assert
    result.Should().ContainSingle();
    result[0].Should().BeOfType<TemporalValidityPeriod>();
    result[0].ValidFromUtc.Should().Be(source.ValidFromUtc);
    result[0].ValidToUtc.Should().Be(source.ValidToUtc);
    result[0].Should().NotBeSameAs(source);
  }

  public static IEnumerable<object[]> InvalidWholeSetCases()
  {
    yield return new object[]
    {
      "null element",
      new TemporalValidityPeriod[] { Period(0, 10), null! },
    };
    yield return new object[]
    {
      "duplicate period",
      new[] { Period(0, 10), Period(0, 10) },
    };
    yield return new object[]
    {
      "duplicate start",
      new[] { Period(0, 10), Period(0, 20) },
    };
    yield return new object[]
    {
      "overlap",
      new[] { Period(0, 20), Period(10, 30) },
    };
    yield return new object[]
    {
      "multiple open ends",
      new[] { Period(0, null), Period(10, null) },
    };
    yield return new object[]
    {
      "bounded period after open end",
      new[] { Period(0, null), Period(10, 20) },
    };
  }

  [Theory]
  [MemberData(nameof(InvalidWholeSetCases))]
  public void Constructor_InvalidWholeSet_ThrowsArgumentExceptionNamingPeriods(
    string caseName,
    IEnumerable<TemporalValidityPeriod> periods)
  {
    // Arrange
    _ = caseName;

    // Act
    var action = () => new TemporalValidityPeriodSet(periods);

    // Assert
    action.Should().Throw<ArgumentException>()
      .Which.ParamName.Should().Be("periods");
  }

  [Fact]
  public void Constructor_ExactAbutmentAndGap_AreValidAndCanonicallyOrdered()
  {
    // Arrange
    var periods = new[] { Period(20, 30), Period(10, 15), Period(0, 10) };

    // Act
    var result = new TemporalValidityPeriodSet(periods);

    // Assert
    result.Should().Equal(Period(0, 10), Period(10, 15), Period(20, 30));
    result[1].Should().Be(Period(10, 15));
    ((IEnumerable)result).Cast<TemporalValidityPeriod>()
      .Should().Equal(Period(0, 10), Period(10, 15), Period(20, 30));
  }

  [Fact]
  public void Equality_DifferentlyOrderedInputs_IsStructuralAcrossSequenceAndHashCode()
  {
    // Arrange
    var left = new TemporalValidityPeriodSet(new[] { Period(20, null), Period(0, 10) });
    var right = new TemporalValidityPeriodSet(new[] { Period(0, 10), Period(20, null) });
    var different = new TemporalValidityPeriodSet(new[] { Period(0, 11), Period(20, null) });
    object leftAsObject = left;
    object boxedRight = right;

    // Act
    var operatorEqual = left == right;
    var operatorNotEqual = left != different;
    var equalsDifferentObjectType = leftAsObject.Equals(new object());
    var equalsNullObject = leftAsObject.Equals(null);

    // Assert
    operatorEqual.Should().BeTrue();
    operatorNotEqual.Should().BeTrue();
    left.Equals(left).Should().BeTrue();
    left.Equals(right).Should().BeTrue();
    left.Equals(boxedRight).Should().BeTrue();
    left.GetHashCode().Should().Be(right.GetHashCode());
    left.Equals(different).Should().BeFalse();
    (left == null).Should().BeFalse();
    (null == (TemporalValidityPeriodSet?)null).Should().BeTrue();
    (left != null).Should().BeTrue();
    equalsNullObject.Should().BeFalse();
    equalsDifferentObjectType.Should().BeFalse();
  }

  [Fact]
  public void IsValidAt_BoundedGapAndOpenEnd_UsesHalfOpenBoundaries()
  {
    // Arrange
    var set = new TemporalValidityPeriodSet(new[] { Period(0, 10), Period(20, null) });

    // Act
    var exactStart = set.IsValidAt(Instant(0));
    var boundedInterior = set.IsValidAt(Instant(9));
    var exactEnd = set.IsValidAt(Instant(10));
    var gap = set.IsValidAt(Instant(15));
    var openStart = set.IsValidAt(Instant(20));
    var openLater = set.IsValidAt(Instant(100));

    // Assert
    exactStart.Should().BeTrue();
    boundedInterior.Should().BeTrue();
    exactEnd.Should().BeFalse();
    gap.Should().BeFalse();
    openStart.Should().BeTrue();
    openLater.Should().BeTrue();
  }

  [Theory]
  [InlineData(10)]
  [InlineData(20)]
  public void Activate_AtAbutmentOrAfterGap_ReturnsNewValidatedSetAndPreservesReceiver(long activationTicks)
  {
    // Arrange
    var original = new TemporalValidityPeriodSet(new[] { Period(0, 10) });

    // Act
    var result = original.Activate(Instant(activationTicks));

    // Assert
    result.Should().Equal(Period(0, 10), Period(activationTicks, null));
    original.Should().Equal(Period(0, 10));
    result.Should().NotBeSameAs(original);
  }

  [Fact]
  public void Activate_ExistingOpenPeriod_ThrowsInvalidOperationAndPreservesReceiver()
  {
    // Arrange
    var original = new TemporalValidityPeriodSet(new[] { Period(0, null) });

    // Act
    var action = () => original.Activate(Instant(20));

    // Assert
    action.Should().Throw<InvalidOperationException>();
    original.Should().Equal(Period(0, null));
  }

  [Fact]
  public void Activate_OverlappingStart_ThrowsArgumentExceptionNamingPeriodsAndPreservesReceiver()
  {
    // Arrange
    var original = new TemporalValidityPeriodSet(new[] { Period(0, 10) });

    // Act
    var action = () => original.Activate(Instant(5));

    // Assert
    action.Should().Throw<ArgumentException>()
      .Which.ParamName.Should().Be("periods");
    original.Should().Equal(Period(0, 10));
  }

  [Fact]
  public void Deactivate_OpenPeriod_ReturnsNewBoundedSetAndPreservesReceiver()
  {
    // Arrange
    var original = new TemporalValidityPeriodSet(new[] { Period(0, 10), Period(20, null) });

    // Act
    var result = original.Deactivate(Instant(30));

    // Assert
    result.Should().Equal(Period(0, 10), Period(20, 30));
    original.Should().Equal(Period(0, 10), Period(20, null));
    result.Should().NotBeSameAs(original);
  }

  [Fact]
  public void Deactivate_NoOpenPeriod_ThrowsInvalidOperationAndPreservesReceiver()
  {
    // Arrange
    var original = new TemporalValidityPeriodSet(new[] { Period(0, 10) });

    // Act
    var action = () => original.Deactivate(Instant(20));

    // Assert
    action.Should().Throw<InvalidOperationException>();
    original.Should().Equal(Period(0, 10));
  }

  [Theory]
  [InlineData(19)]
  [InlineData(20)]
  public void Deactivate_EndNotLaterThanOpenStart_ThrowsNamingValidToUtcAndPreservesReceiver(long endTicks)
  {
    // Arrange
    var original = new TemporalValidityPeriodSet(new[] { Period(0, 10), Period(20, null) });

    // Act
    var action = () => original.Deactivate(Instant(endTicks));

    // Assert
    action.Should().Throw<ArgumentOutOfRangeException>()
      .Which.ParamName.Should().Be("validToUtc");
    original.Should().Equal(Period(0, 10), Period(20, null));
  }

  [Fact]
  public void Replace_StructurallyEqualMember_ReturnsNewValidatedSetAndPreservesReceiver()
  {
    // Arrange
    var originalMember = Period(0, 10);
    var original = new TemporalValidityPeriodSet(new[] { originalMember, Period(20, 30) });
    var equalButDistinctMember = Period(0, 10);
    var replacement = Period(0, 15);

    // Act
    var result = original.Replace(equalButDistinctMember, replacement);

    // Assert
    result.Should().Equal(replacement, Period(20, 30));
    original.Should().Equal(originalMember, Period(20, 30));
    result.Should().NotBeSameAs(original);
  }

  [Fact]
  public void Replace_AbsentCurrent_ThrowsArgumentExceptionNamingCurrent()
  {
    // Arrange
    var original = new TemporalValidityPeriodSet(new[] { Period(0, 10) });

    // Act
    var action = () => original.Replace(Period(20, 30), Period(20, 40));

    // Assert
    action.Should().Throw<ArgumentException>()
      .Which.ParamName.Should().Be("current");
  }

  [Fact]
  public void Replace_NullArguments_ThrowArgumentNullExceptionNamingArgument()
  {
    // Arrange
    var original = new TemporalValidityPeriodSet(new[] { Period(0, 10) });

    // Act
    var nullCurrent = () => original.Replace(null!, Period(0, 5));
    var nullReplacement = () => original.Replace(Period(0, 10), null!);

    // Assert
    nullCurrent.Should().Throw<ArgumentNullException>()
      .Which.ParamName.Should().Be("current");
    nullReplacement.Should().Throw<ArgumentNullException>()
      .Which.ParamName.Should().Be("replacement");
  }

  [Fact]
  public void Replace_OverlappingReplacement_ThrowsArgumentExceptionNamingPeriodsAndPreservesReceiver()
  {
    // Arrange
    var original = new TemporalValidityPeriodSet(new[] { Period(0, 10), Period(20, 30) });

    // Act
    var action = () => original.Replace(Period(0, 10), Period(0, 25));

    // Assert
    action.Should().Throw<ArgumentException>()
      .Which.ParamName.Should().Be("periods");
    original.Should().Equal(Period(0, 10), Period(20, 30));
  }

  [Fact]
  public void Split_BoundedPeriodAtStrictInterior_ReturnsTwoAbuttingPeriodsAndPreservesReceiver()
  {
    // Arrange
    var current = Period(0, 10);
    var original = new TemporalValidityPeriodSet(new[] { current, Period(20, 30) });

    // Act
    var result = original.Split(Period(0, 10), Instant(5));

    // Assert
    result.Should().Equal(Period(0, 5), Period(5, 10), Period(20, 30));
    original.Should().Equal(current, Period(20, 30));
  }

  [Fact]
  public void Split_OpenPeriodAtStrictInterior_PreservesOpenEndOnLaterHalf()
  {
    // Arrange
    var original = new TemporalValidityPeriodSet(new[] { Period(20, null) });

    // Act
    var result = original.Split(Period(20, null), Instant(25));

    // Assert
    result.Should().Equal(Period(20, 25), Period(25, null));
    original.Should().Equal(Period(20, null));
  }

  [Theory]
  [InlineData(-1)]
  [InlineData(0)]
  [InlineData(10)]
  [InlineData(11)]
  public void Split_OutsideStrictInterior_ThrowsNamingSplitAtUtcAndPreservesReceiver(long splitTicks)
  {
    // Arrange
    var original = new TemporalValidityPeriodSet(new[] { Period(0, 10) });

    // Act
    var action = () => original.Split(Period(0, 10), Instant(splitTicks));

    // Assert
    action.Should().Throw<ArgumentOutOfRangeException>()
      .Which.ParamName.Should().Be("splitAtUtc");
    original.Should().Equal(Period(0, 10));
  }

  [Fact]
  public void Split_AbsentOrNullCurrent_ThrowsNamingCurrent()
  {
    // Arrange
    var original = new TemporalValidityPeriodSet(new[] { Period(0, 10) });

    // Act
    var absent = () => original.Split(Period(20, 30), Instant(25));
    var nullCurrent = () => original.Split(null!, Instant(5));

    // Assert
    absent.Should().Throw<ArgumentException>()
      .Which.ParamName.Should().Be("current");
    nullCurrent.Should().Throw<ArgumentNullException>()
      .Which.ParamName.Should().Be("current");
  }

  [Fact]
  public void Merge_ConsecutiveAbuttingBoundedPeriods_ReturnsCombinedPeriodAndPreservesReceiver()
  {
    // Arrange
    var original = new TemporalValidityPeriodSet(new[] { Period(0, 10), Period(10, 20), Period(30, 40) });

    // Act
    var result = original.Merge(Period(0, 10), Period(10, 20));

    // Assert
    result.Should().Equal(Period(0, 20), Period(30, 40));
    original.Should().Equal(Period(0, 10), Period(10, 20), Period(30, 40));
  }

  [Fact]
  public void Merge_ConsecutiveAbuttingOpenLaterPeriod_PreservesOpenEnd()
  {
    // Arrange
    var original = new TemporalValidityPeriodSet(new[] { Period(0, 10), Period(10, null) });

    // Act
    var result = original.Merge(Period(0, 10), Period(10, null));

    // Assert
    result.Should().Equal(Period(0, null));
    original.Should().Equal(Period(0, 10), Period(10, null));
  }

  [Fact]
  public void Merge_GappedOrReversedMembers_ThrowsArgumentExceptionNamingLaterAndPreservesReceiver()
  {
    // Arrange
    var original = new TemporalValidityPeriodSet(new[] { Period(0, 10), Period(20, 30) });

    // Act
    var gapped = () => original.Merge(Period(0, 10), Period(20, 30));
    var reversed = () => original.Merge(Period(20, 30), Period(0, 10));

    // Assert
    gapped.Should().Throw<ArgumentException>()
      .Which.ParamName.Should().Be("later");
    reversed.Should().Throw<ArgumentException>()
      .Which.ParamName.Should().Be("later");
    original.Should().Equal(Period(0, 10), Period(20, 30));
  }

  [Fact]
  public void Merge_AbsentMembers_ThrowArgumentExceptionNamingAbsentArgument()
  {
    // Arrange
    var original = new TemporalValidityPeriodSet(new[] { Period(0, 10), Period(10, 20) });

    // Act
    var absentEarlier = () => original.Merge(Period(-10, 0), Period(10, 20));
    var absentLater = () => original.Merge(Period(0, 10), Period(20, 30));

    // Assert
    absentEarlier.Should().Throw<ArgumentException>()
      .Which.ParamName.Should().Be("earlier");
    absentLater.Should().Throw<ArgumentException>()
      .Which.ParamName.Should().Be("later");
  }

  [Fact]
  public void Merge_NullMembers_ThrowArgumentNullExceptionNamingArgument()
  {
    // Arrange
    var original = new TemporalValidityPeriodSet(new[] { Period(0, 10), Period(10, 20) });

    // Act
    var nullEarlier = () => original.Merge(null!, Period(10, 20));
    var nullLater = () => original.Merge(Period(0, 10), null!);

    // Assert
    nullEarlier.Should().Throw<ArgumentNullException>()
      .Which.ParamName.Should().Be("earlier");
    nullLater.Should().Throw<ArgumentNullException>()
      .Which.ParamName.Should().Be("later");
  }

  private static TemporalValidityPeriod Period(long startTicks, long? endTicks) =>
    new(Instant(startTicks), endTicks.HasValue ? Instant(endTicks.Value) : null);

  private static UtcInstant Instant(long offsetTicks) => new(DateTimeOffset.UnixEpoch.AddTicks(offsetTicks));

  private sealed class SinglePassEnumerable : IEnumerable<TemporalValidityPeriod>
  {
    private readonly IEnumerable<TemporalValidityPeriod> source;

    public SinglePassEnumerable(IEnumerable<TemporalValidityPeriod> source)
    {
      this.source = source;
    }

    public int EnumerationCount { get; private set; }

    public IEnumerator<TemporalValidityPeriod> GetEnumerator()
    {
      EnumerationCount++;
      if (EnumerationCount > 1)
      {
        throw new InvalidOperationException("The source was enumerated more than once.");
      }

      return source.GetEnumerator();
    }

    IEnumerator IEnumerable.GetEnumerator() => GetEnumerator();
  }

  private sealed class TestTemporalValidityPeriod : ITemporalValidityPeriod
  {
    public TestTemporalValidityPeriod(UtcInstant validFromUtc, UtcInstant? validToUtc)
    {
      ValidFromUtc = validFromUtc;
      ValidToUtc = validToUtc;
    }

    public UtcInstant ValidFromUtc { get; }

    public UtcInstant? ValidToUtc { get; }

    public bool IsOpenEnded => ValidToUtc is null;

    public TemporalDuration? Duration => ValidToUtc is { } end
      ? new TemporalDuration(end.Value - ValidFromUtc.Value)
      : null;

    public bool Contains(UtcInstant instant) => instant.CompareTo(ValidFromUtc) >= 0
      && (ValidToUtc is null || instant.CompareTo(ValidToUtc.Value) < 0);
  }
}
