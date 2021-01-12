using System;
using ATAP.Utilities.TypedGuids;
using Itenso.TimePeriod;
using System.Collections.Generic;

namespace ATAP.Utilities.Philote
{
    public interface IGuidPhilote2<T> : IPhilote2<T, Guid> where T : notnull{}
    public interface IIntPhilote2<T> : IPhilote2<T, int> where T : notnull{}

  public interface IPhilote2<T, TValue> where T : notnull where TValue : notnull
  {
    IStronglyTypedId<TValue> ID { get; }
    IDictionary<string, IStronglyTypedId<TValue>> AdditionalIDs { get; }
    //public IConcurrentObservableDictionary<IIdAsStruct<T>) SecondaryIDs { get; private set; }
    IEnumerable<ITimeBlock> TimeBlocks { get; }
  }

  public interface IPhilote<T>
  {
    IIdAsStruct<T> ID { get; }
    IDictionary<string, IIdAsStruct<T>> AdditionalIDs { get; }
    //public IConcurrentObservableDictionary<IIdAsStruct<T>) SecondaryIDs { get; private set; }

    IEnumerable<ITimeBlock> TimeBlocks { get; }
  }
}
