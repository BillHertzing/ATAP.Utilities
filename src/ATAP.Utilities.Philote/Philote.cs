using System;
using System.Collections.Generic;
using System.Collections.Concurrent;
using System.Linq;
using ATAP.Utilities.StronglyTypedID;
using Itenso.TimePeriod;

namespace ATAP.Utilities.Philote
{
  public abstract record AbstractPhilote<T, TValue> : IAbstractPhilote<T, TValue> where T : class where TValue : notnull {

    public AbstractPhilote(IStronglyTypedID<TValue> iD = default, ConcurrentDictionary<string, IStronglyTypedID<TValue>>? additionalIDs = default, IEnumerable<ITimeBlock>? timeBlocks = default) {
      if (iD != default) { ID = iD; }
      else {
        ID = (typeof(TValue)) switch {
          Type intType when typeof(TValue) == typeof(int) => (IStronglyTypedID<TValue>)new IntStronglyTypedID() { Value = new Random().Next() },
          Type GuidType when typeof(TValue) == typeof(Guid) => (IStronglyTypedID<TValue>)new GuidStronglyTypedID() { Value = Guid.NewGuid() },
          // ToDo: replace with new custom exception and localization of exception message
          _ => throw new Exception(FormattableString.Invariant($"Invalid TValue type {typeof(TValue)}")),

        };
      }
      AdditionalIDs = additionalIDs != default ? additionalIDs : new ConcurrentDictionary<string, IStronglyTypedID<TValue>>();
      TimeBlocks = timeBlocks != default ? timeBlocks : new List<ITimeBlock>();
    }

    public IStronglyTypedID<TValue> ID { get; init; }
    public ConcurrentDictionary<string, IStronglyTypedID<TValue>>? AdditionalIDs { get; init; }
    public IEnumerable<ITimeBlock>? TimeBlocks { get; init; }
  }

// record TestClassGuidTypedId  : StronglyTypedID<Guid>  {

// }
// record TestClassIntTypedId  : StronglyTypedID<int>  {
// }
// class Testclass {

  // Philote2<Testclass,Guid> Philote2GuidEmpty {get;}
  // Philote2<Testclass,int> Philote2IntEmpty {get;}
  // Philote2<Testclass,Guid> Philote2GuidRandom {get;}
  // Philote2<Testclass,int> Philote2IntRandom {get;}
  // Philote2<Testclass,Guid> Philote2GuidNow {get;}
  // Philote2<Testclass,int> Philote2IntNow {get;}
  // Testclass(){
    // Philote2GuidEmpty = new Philote2<Testclass,Guid>();
    // Philote2IntEmpty = new Philote2<Testclass,int>();
    // Philote2GuidRandom = new Philote2<Testclass,Guid>(){ID = new GuidStronglyTypedID(){Value =  Guid.NewGuid()}};
    // Philote2IntRandom = new Philote2<Testclass,int>() {ID = new IntStronglyTypedID(){Value =  new Random().Next()}};
    // Philote2GuidNow = new Philote2<Testclass,Guid>() {ID = new GuidStronglyTypedID(){Value =  Guid.NewGuid()}, TimeBlocks = new List<ITimeBlock>() { new TimeBlock(DateTime.Now) }};
    // Philote2IntNow = new Philote2<Testclass,int>(){ID = new IntStronglyTypedID(){Value =  new Random().Next()}, TimeBlocks = new List<ITimeBlock>() { new TimeBlock(DateTime.Now) }};
  // }
// }
  // public class Philote2<T, TValue> : IPhilote2<T, TValue> where T : notnull where TValue : notnull
  // {
    // // public Philote2() : this ((IStronglyTypedID<TValue>) randomTValue(), new Dictionary<string, IStronglyTypedID<TValue>>(), new List<ITimeBlock>()) { }
    // // public Philote2(StronglyTypedID<TValue> id) : this(id, new Dictionary<string, IStronglyTypedID<TValue>>(), new List<ITimeBlock>()) { }
    // // public Philote2(IList<ITimeBlock> timeBlocks) : this((IStronglyTypedID<TValue>) randomTValue(), new Dictionary<string, IStronglyTypedID<TValue>>(), timeBlocks) { }
    // // public Philote2(StronglyTypedID<TValue> id, IList<ITimeBlock> timeBlocks) : this(id, new Dictionary<string, IStronglyTypedID<TValue>>(), timeBlocks) { }
    // // public Philote2(IStronglyTypedID<TValue> iD, IDictionary<string, IStronglyTypedID<TValue>> additionalIDs, IEnumerable<ITimeBlock> timeBlocks)
    // // {
    // //   ID = iD;
    // //   AdditionalIDs = additionalIDs;
    // //   TimeBlocks = timeBlocks;
    // // }
    // public Philote2(IStronglyTypedID<TValue> iD = default, IDictionary<string, IStronglyTypedID<TValue>> additionalIDs = default, IEnumerable<ITimeBlock> timeBlocks = default)
    // {
      // if (iD != default) {ID = iD;} else {
            // ID = (typeof(TValue)) switch {
        // Type intType when typeof(TValue)  == typeof(int) => (IStronglyTypedID<TValue>)new IntStronglyTypedID(){Value =  new Random().Next()},
        // Type GuidType when typeof(TValue)  == typeof(Guid) => (IStronglyTypedID<TValue>)new GuidStronglyTypedID(){Value =  Guid.NewGuid()},
        // _ => throw new Exception(String.Format("Invalid TValue type {0}", typeof(TValue))),
      // };
      // }
      // AdditionalIDs = additionalIDs != default ? additionalIDs : new Dictionary<string, IStronglyTypedID<TValue>>();
      // TimeBlocks = timeBlocks  != default ? timeBlocks :new List<ITimeBlock>();
    // }

    // public IStronglyTypedID<TValue> ID { get; init; }
    // public IDictionary<string, IStronglyTypedID<TValue>> AdditionalIDs { get; init; }
    // //public IConcurrentObservableDictionary<string,IStronglyTypedID<TValue>) SecondaryIDs { get; private set; }
    // public IEnumerable<ITimeBlock> TimeBlocks { get; init; }
  // }

  // public class Philote<T> : IPhilote<T>
  // {
    // public Philote<T> Now() {
      // return new Philote<T>(new IdAsStruct<T>(Guid.NewGuid()), new Dictionary<string, IIdAsStruct<T>>(), new List<ITimeBlock>() { new TimeBlock(DateTime.Now) });
    // }

    // public Philote() : this (new IdAsStruct<T>(Guid.NewGuid()), new Dictionary<string, IIdAsStruct<T>>(), new List<ITimeBlock>()) { }

    // public Philote(IdAsStruct<T> id) : this(id, new Dictionary<string, IIdAsStruct<T>>(), new List<ITimeBlock>()) { }

    // public Philote(IIdAsStruct<T> iD, IDictionary<string, IIdAsStruct<T>> additionalIDs, IEnumerable<ITimeBlock> timeBlocks)
    // {
      // ID = iD;
      // AdditionalIDs = additionalIDs;
      // TimeBlocks = timeBlocks;
    // }

    // public IIdAsStruct<T> ID { get; private set; }
    // public IDictionary<string, IIdAsStruct<T>> AdditionalIDs { get; private set; }
    // //public IConcurrentObservableDictionary<string,IIdAsStruct<T>) SecondaryIDs { get; private set; }
    // public IEnumerable<ITimeBlock> TimeBlocks { get; private set; }
  // }
}
