using ATAP.Utilities.TypedGuids;
using Itenso.TimePeriod;
using System;
using System.Collections.Generic;
using System.Linq;

namespace ATAP.Utilities.Philote
{

  public class Philote<T> : IPhilote<T>
  {
    public Philote<T> Now() {
      return new Philote<T>(new Id<T>(Guid.NewGuid()), new Dictionary<string, IId<T>>(), new List<ITimeBlock>() { new TimeBlock(DateTime.Now) });
    }

    public Philote() : this (new Id<T>(Guid.NewGuid()), new Dictionary<string, IId<T>>(), new List<ITimeBlock>()) { }

    public Philote(Id<T> id) : this(id, new Dictionary<string, IId<T>>(), new List<ITimeBlock>()) { }

    public Philote(IId<T> iD, IDictionary<string, IId<T>> additionalIDs, IEnumerable<ITimeBlock> timeBlocks)
    {
      ID = iD;
      AdditionalIDs = additionalIDs;
      TimeBlocks = timeBlocks;
    }

    public IId<T> ID { get; private set; }
    public IDictionary<string, IId<T>> AdditionalIDs { get; private set; }
    //public IConcurrentObservableDictionary<string,IId<T>) SecondaryIDs { get; private set; }
    public IEnumerable<ITimeBlock> TimeBlocks { get; private set; }
  }
}
