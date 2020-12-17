using System;
using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public interface IGNamespace {
    string GName { get; init; }
    Dictionary<IPhilote<IGClass>, IGClass> GClasss { get; init; }
    Dictionary<IPhilote<IGInterface>, IGInterface> GInterfaces { get; init; }
    Dictionary<IPhilote<IGDelegate>, IGDelegate> GDelegates { get; init; }
    Dictionary<IPhilote<IGDelegateGroup>, IGDelegateGroup> GDelegateGroups { get; init; }
    Dictionary<IPhilote<IGEnumeration>, IGEnumeration> GEnumerations { get; init; }
    Dictionary<IPhilote<IGEnumerationGroup>, IGEnumerationGroup> GEnumerationGroups { get; init; }
    IGComment GComment { get; init; }
    IPhilote<IGNamespace> Philote { get; init; }
  }
}
