using ATAP.Utilities.StronglyTypedID;
using Itenso.TimePeriod;
using System;
using System.Collections.Generic;

namespace ATAP.Utilities.Philote
{
  public static class DefaultConfiguration<T>
  {
    public static IDictionary<string, IPhilote<T>> Production = new Dictionary<string, IPhilote<T>>() {
        { "Generic", new Philote<T>(new IdAsStruct<T>(),new Dictionary<string, IIdAsStruct<T>>(), new List<ITimeBlock>())},
        { "Contrived", new Philote<T>(new IdAsStruct<T>(new Guid("01234567-abcd-9876-cdef-456789abcdef")),new Dictionary<string, IIdAsStruct<T>>(), new List<ITimeBlock>())},
      };
  }

}
