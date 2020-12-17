using System;
using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public interface IGNamespace {
    string GName { get; init; }
    IDictionary<IPhilote<IGClass>, IGClass> GClasss { get; init; }
    IDictionary<IPhilote<IGInterface>, IGInterface> GInterfaces { get; init; }
    IDictionary<IPhilote<IGDelegate>, IGDelegate> GDelegates { get; init; }
    IDictionary<IPhilote<IGDelegateGroup>, IGDelegateGroup> GDelegateGroups { get; init; }
    IDictionary<IPhilote<IGEnumeration>, IGEnumeration> GEnumerations { get; init; }
    IDictionary<IPhilote<IGEnumerationGroup>, IGEnumerationGroup> GEnumerationGroups { get; init; }
    IGComment GComment { get; init; }
    IPhilote<IGNamespace> Philote { get; init; }
  }
}
