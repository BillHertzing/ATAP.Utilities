using System;
using System.Collections.Generic;
using ATAP.Utilities.DateTime.Interfaces;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.Philote;

public interface IGuidPhilote<TId> : IAbstractPhilote<TId, Guid>
  where TId : IAbstractStronglyTypedId<Guid>, new()
{
}

public interface IIntPhilote<TId> : IAbstractPhilote<TId, int>
  where TId : IAbstractStronglyTypedId<int>, new()
{
}

public interface IAbstractPhilote<TId, TValue>
  where TId : IAbstractStronglyTypedId<TValue>, new()
  where TValue : notnull
{
  TId Id { get; }

  IReadOnlyDictionary<string, IAbstractStronglyTypedId<TValue>> AdditionalIds { get; }

  IReadOnlyList<ITemporalValidityPeriod> ValidityPeriods { get; }

  bool IsValidAt(UtcInstant instant);
}
