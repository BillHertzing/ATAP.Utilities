using ATAP.Utilities.StronglyTypedId;
using Itenso.TimePeriod;
using System;
using System.Collections.Generic;

namespace ATAP.Utilities.Philote
{
  // TODO: Migrate to new Philote API - old IPhilote<T>, Philote<T>, IdAsStruct<T>, IIdAsStruct<T> no longer exist
  // Use IGuidPhilote<TId>/IIntPhilote<TId> with GuidPhilote<TId>/IntPhilote<TId> and GuidStronglyTypedId/IntStronglyTypedId
  /*
  public static class DefaultConfiguration<T>
  {
    public static IDictionary<string, IPhilote<T>> Production = new Dictionary<string, IPhilote<T>>() {
        { "Generic", new Philote<T>(new IdAsStruct<T>(),new Dictionary<string, IIdAsStruct<T>>(), new List<ITimeBlock>())},
        { "Contrived", new Philote<T>(new IdAsStruct<T>(new Guid("01234567-abcd-9876-cdef-456789abcdef")),new Dictionary<string, IIdAsStruct<T>>(), new List<ITimeBlock>())},
      };
  }
  */

}
