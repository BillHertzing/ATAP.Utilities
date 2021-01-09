using ATAP.Utilities.TypedGuids;
using Itenso.TimePeriod;
using System;
using System.Collections.Generic;
using System.Linq;

namespace ATAP.Utilities.Philote
{

class Testclass {
  Philote2<Testclass,Guid> Philote2Guid {get;}
  Philote2<Testclass,int> Philote2Int {get;}
  Philote2<Testclass,Guid> Philote2GuidNow {get;}
  Philote2<Testclass,int> Philote2IntNow {get;}
  Testclass(){
    Philote2Guid = new Philote2<Testclass,Guid>();
    Philote2Int = new Philote2<Testclass,int>();
    Philote2GuidNow = new Philote2<Testclass,Guid>(new List<ITimeBlock>() { new TimeBlock(DateTime.Now) });
    Philote2IntNow = new Philote2<Testclass,int>().Now();
  }
}
  public record Philote2<T, TValue> : IPhilote2<T, TValue> where T : notnull where TValue : notnull
  {

    public Philote2<T, TValue> Now() {
      return new Philote2<T, TValue>((IStronglyTypedId<TValue>) randomTValue(), new Dictionary<string, IStronglyTypedId<TValue>>(), new List<ITimeBlock>() { new TimeBlock(DateTime.Now) });
    }

    private static TValue randomTValue()  {
      switch (typeof(TValue)) {
        case Type intType when intType == typeof(int):
        var random = new Random();
        return (TValue) random.Next(); // Compiletime error
        case Type GuidType when GuidType == typeof(Guid):
        return (TValue)Guid.NewGuid();  // Compiletime error
        default:
        throw new Exception(String.Format("Invalid TValue type {0}", typeof(TValue)));
      }
    }

    public Philote2() : this ((IStronglyTypedId<TValue>) randomTValue(), new Dictionary<string, IStronglyTypedId<TValue>>(), new List<ITimeBlock>()) { }
    public Philote2(StronglyTypedId<TValue> id) : this(id, new Dictionary<string, IStronglyTypedId<TValue>>(), new List<ITimeBlock>()) { }
    public Philote2(IList<ITimeBlock> timeBlocks) : this((IStronglyTypedId<TValue>) randomTValue(), new Dictionary<string, IStronglyTypedId<TValue>>(), timeBlocks) { }
    public Philote2(StronglyTypedId<TValue> id, IList<ITimeBlock> timeBlocks) : this(id, new Dictionary<string, IStronglyTypedId<TValue>>(), timeBlocks) { }
    public Philote2(IStronglyTypedId<TValue> iD, IDictionary<string, IStronglyTypedId<TValue>> additionalIDs, IEnumerable<ITimeBlock> timeBlocks)
    {
      ID = iD;
      AdditionalIDs = additionalIDs;
      TimeBlocks = timeBlocks;
    }

    public IStronglyTypedId<TValue> ID { get; init; }
    public IDictionary<string, IStronglyTypedId<TValue>> AdditionalIDs { get; init; }
    //public IConcurrentObservableDictionary<string,IStronglyTypedId<TValue>) SecondaryIDs { get; private set; }
    public IEnumerable<ITimeBlock> TimeBlocks { get; init; }
  }

  public class Philote<T> : IPhilote<T>
  {
    public Philote<T> Now() {
      return new Philote<T>(new IdAsStruct<T>(Guid.NewGuid()), new Dictionary<string, IIdAsStruct<T>>(), new List<ITimeBlock>() { new TimeBlock(DateTime.Now) });
    }

    public Philote() : this (new IdAsStruct<T>(Guid.NewGuid()), new Dictionary<string, IIdAsStruct<T>>(), new List<ITimeBlock>()) { }

    public Philote(IdAsStruct<T> id) : this(id, new Dictionary<string, IIdAsStruct<T>>(), new List<ITimeBlock>()) { }

    public Philote(IIdAsStruct<T> iD, IDictionary<string, IIdAsStruct<T>> additionalIDs, IEnumerable<ITimeBlock> timeBlocks)
    {
      ID = iD;
      AdditionalIDs = additionalIDs;
      TimeBlocks = timeBlocks;
    }

    public IIdAsStruct<T> ID { get; private set; }
    public IDictionary<string, IIdAsStruct<T>> AdditionalIDs { get; private set; }
    //public IConcurrentObservableDictionary<string,IIdAsStruct<T>) SecondaryIDs { get; private set; }
    public IEnumerable<ITimeBlock> TimeBlocks { get; private set; }
  }
}
