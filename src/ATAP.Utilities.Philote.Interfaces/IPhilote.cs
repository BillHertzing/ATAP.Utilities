using System;
using ATAP.Utilities.StronglyTypedId;
using Itenso.TimePeriod;
using System.Collections.Generic;
using System.Collections.Concurrent;

namespace ATAP.Utilities.Philote {
  public interface IGuidPhilote<TId> : IAbstractPhilote<TId, Guid> where TId : IAbstractStronglyTypedId<Guid>, new() { }
  public interface IIntPhilote<TId> : IAbstractPhilote<TId, int> where TId : IAbstractStronglyTypedId<int>, new() { }

  public interface IAbstractPhilote<TId, TValue> where TId: IAbstractStronglyTypedId<TValue>, new() where TValue : notnull {
    TId Id { get; }
    ConcurrentDictionary<string, IAbstractStronglyTypedId<TValue>>? AdditionalIds { get; }
    IEnumerable<ITimeBlock>? TimeBlocks { get; }
  }
}
