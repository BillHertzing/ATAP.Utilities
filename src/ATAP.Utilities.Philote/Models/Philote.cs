using System;
using System.Collections.Generic;
using System.Collections.Immutable;
using System.Linq;
using ATAP.Utilities.DateTime.Interfaces;
using ATAP.Utilities.DateTime.Model;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.Philote;

public abstract class AbstractPhilote<TId, TValue> : IAbstractPhilote<TId, TValue>
  where TId : AbstractStronglyTypedId<TValue>, new()
  where TValue : notnull
{
  private readonly ImmutableDictionary<string, IAbstractStronglyTypedId<TValue>> _additionalIds;
  private readonly TemporalValidityPeriodSet _validityPeriodSet;

  protected AbstractPhilote(
    TId? id = default,
    IEnumerable<KeyValuePair<string, IAbstractStronglyTypedId<TValue>>>? additionalIds = default,
    IEnumerable<TemporalValidityPeriod>? validityPeriods = default)
  {
    Id = id ?? new TId();
    _additionalIds = MaterializeAdditionalIds(additionalIds);
    _validityPeriodSet = new TemporalValidityPeriodSet(validityPeriods);
  }

  public TId Id { get; }

  public IReadOnlyDictionary<string, IAbstractStronglyTypedId<TValue>> AdditionalIds => _additionalIds;

  public IReadOnlyList<TemporalValidityPeriod> ValidityPeriods => _validityPeriodSet;

  protected TemporalValidityPeriodSet ValidityPeriodSet => _validityPeriodSet;

  public bool IsValidAt(UtcInstant instant) => _validityPeriodSet.IsValidAt(instant);

  public override bool Equals(object? obj) =>
    obj is AbstractPhilote<TId, TValue> other
    && other.GetType() == GetType()
    && EqualityComparer<TId>.Default.Equals(Id, other.Id);

  public override int GetHashCode() => HashCode.Combine(GetType(), Id);

  private static ImmutableDictionary<string, IAbstractStronglyTypedId<TValue>> MaterializeAdditionalIds(
    IEnumerable<KeyValuePair<string, IAbstractStronglyTypedId<TValue>>>? additionalIds)
  {
    if (additionalIds is null)
    {
      return ImmutableDictionary<string, IAbstractStronglyTypedId<TValue>>.Empty;
    }

    var builder = ImmutableDictionary.CreateBuilder<string, IAbstractStronglyTypedId<TValue>>(StringComparer.Ordinal);
    foreach (var pair in additionalIds)
    {
      if (pair.Key is null)
      {
        throw new ArgumentException("An additional ID key cannot be null.", nameof(additionalIds));
      }

      if (pair.Value is null)
      {
        throw new ArgumentException("An additional ID value cannot be null.", nameof(additionalIds));
      }

      if (!builder.TryAdd(pair.Key, pair.Value))
      {
        throw new ArgumentException("Additional ID keys must be unique.", nameof(additionalIds));
      }
    }

    return builder.ToImmutable();
  }
}

public sealed class IntPhilote<TId> : AbstractPhilote<TId, int>, IIntPhilote<TId>
  where TId : IntStronglyTypedId, new()
{
  public IntPhilote()
  {
  }

  public IntPhilote(TId id)
    : base(id)
  {
  }

  public IntPhilote(
    TId? id,
    IEnumerable<KeyValuePair<string, IAbstractStronglyTypedId<int>>>? additionalIds,
    IEnumerable<TemporalValidityPeriod>? validityPeriods)
    : base(id, additionalIds, validityPeriods)
  {
  }

  public IntPhilote<TId> Activate(UtcInstant validFromUtc) => With(ValidityPeriodSet.Activate(validFromUtc));

  public IntPhilote<TId> Deactivate(UtcInstant validToUtc) => With(ValidityPeriodSet.Deactivate(validToUtc));

  public IntPhilote<TId> Replace(TemporalValidityPeriod current, TemporalValidityPeriod replacement) =>
    With(ValidityPeriodSet.Replace(current, replacement));

  public IntPhilote<TId> Split(TemporalValidityPeriod current, UtcInstant splitAtUtc) =>
    With(ValidityPeriodSet.Split(current, splitAtUtc));

  public IntPhilote<TId> Merge(TemporalValidityPeriod earlier, TemporalValidityPeriod later) =>
    With(ValidityPeriodSet.Merge(earlier, later));

  private IntPhilote<TId> With(TemporalValidityPeriodSet periods) => new(Id, AdditionalIds, periods);
}

public sealed class GuidPhilote<TId> : AbstractPhilote<TId, Guid>, IGuidPhilote<TId>
  where TId : GuidStronglyTypedId, new()
{
  public GuidPhilote()
  {
  }

  public GuidPhilote(TId id)
    : base(id)
  {
  }

  public GuidPhilote(
    TId? id,
    IEnumerable<KeyValuePair<string, IAbstractStronglyTypedId<Guid>>>? additionalIds,
    IEnumerable<TemporalValidityPeriod>? validityPeriods)
    : base(id, additionalIds, validityPeriods)
  {
  }

  public GuidPhilote<TId> Activate(UtcInstant validFromUtc) => With(ValidityPeriodSet.Activate(validFromUtc));

  public GuidPhilote<TId> Deactivate(UtcInstant validToUtc) => With(ValidityPeriodSet.Deactivate(validToUtc));

  public GuidPhilote<TId> Replace(TemporalValidityPeriod current, TemporalValidityPeriod replacement) =>
    With(ValidityPeriodSet.Replace(current, replacement));

  public GuidPhilote<TId> Split(TemporalValidityPeriod current, UtcInstant splitAtUtc) =>
    With(ValidityPeriodSet.Split(current, splitAtUtc));

  public GuidPhilote<TId> Merge(TemporalValidityPeriod earlier, TemporalValidityPeriod later) =>
    With(ValidityPeriodSet.Merge(earlier, later));

  private GuidPhilote<TId> With(TemporalValidityPeriodSet periods) => new(Id, AdditionalIds, periods);
}
