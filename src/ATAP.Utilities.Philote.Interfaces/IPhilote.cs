using ATAP.Utilities.TypedGuids;
using Itenso.TimePeriod;
using System.Collections.Generic;

namespace ATAP.Utilities.Philote
{

  public interface IPhilote<T>
  {
    IId<T> ID { get; }
    IDictionary<string, IId<T>> AdditionalIDs { get; }
    //public IConcurrentObservableDictionary<IId<T>) SecondaryIDs { get; private set; }

    IEnumerable<ITimeBlock> TimeBlocks { get; }
  }
}
