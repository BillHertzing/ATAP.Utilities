using System;
using System.Collections.Generic;
using System.Collections.Concurrent;
using ATAP.Utilities.StronglyTypedID;
using Itenso.TimePeriod;

namespace ATAP.Utilities.Philote
{
  public interface IAbstractPhilote<T, TValue> where T : class where TValue : notnull
  {
    IStronglyTypedID<TValue> ID { get; }
    ConcurrentDictionary<string, IStronglyTypedID<TValue>>? AdditionalIDs { get; }
    IEnumerable<ITimeBlock>? TimeBlocks { get; }
  }

  //   public interface IGuidPhilote<T> : IAbstractPhilote<T, Guid> where T : class{}
  //   public interface IIntPhilote<T> : IAbstractPhilote<T, int> where T : class{}

  //   public interface IGuidPhilote2<T> : IPhilote2<T, Guid> where T : notnull{}
  //   public interface IIntPhilote2<T> : IPhilote2<T, int> where T : notnull{}

  // public interface IPhilote2<T, TValue> where T : notnull where TValue : notnull
  // {
  //   IStronglyTypedID<TValue> ID { get; }
  //   IDictionary<string, IStronglyTypedID<TValue>> AdditionalIDs { get; }
  //   //public IConcurrentObservableDictionary<IIdAsStruct<T>) SecondaryIDs { get; private set; }
  //   IEnumerable<ITimeBlock> TimeBlocks { get; }
  // }

  // public interface IPhilote<T>
  // {
  //   IIdAsStruct<T> ID { get; }
  //   IDictionary<string, IIdAsStruct<T>> AdditionalIDs { get; }
  //   //public IConcurrentObservableDictionary<IIdAsStruct<T>) SecondaryIDs { get; private set; }

  //   IEnumerable<ITimeBlock> TimeBlocks { get; }
  // }
}
