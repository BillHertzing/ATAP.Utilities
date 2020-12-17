using System;
using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {

  public class GNamespace : IGNamespace {
    public GNamespace(string gName = "", IDictionary<IPhilote<IGClass>, IGClass>? gClasss = default,
      IDictionary<IPhilote<IGInterface>, IGInterface>? gInterfaces = default,
      IDictionary<IPhilote<IGDelegate>, IGDelegate>? gDelegates = default,
      IDictionary<IPhilote<IGDelegateGroup>, IGDelegateGroup>? gDelegateGroups = default,
      IDictionary<IPhilote<IGEnumeration>, IGEnumeration>? gEnumerations = default,
      IDictionary<IPhilote<IGEnumerationGroup>, IGEnumerationGroup>? gEnumerationGroups = default,
      //IDictionary<IPhilote<IGEnumeration>, IGEnumeration>? gEnumerations = default,
      //IDictionary<IPhilote<IGException>, IGException>? gExceptions = default
      IGComment gComment = default

      ) {
      GName = gName;
      GClasss = gClasss == default ? new Dictionary<IPhilote<IGClass>, IGClass>() : gClasss;
      GInterfaces = gInterfaces == default ? new Dictionary<IPhilote<IGInterface>, IGInterface>() : gInterfaces;
      GDelegates = gDelegates == default ? new Dictionary<IPhilote<IGDelegate>, IGDelegate>() : gDelegates;
      GDelegateGroups = gDelegateGroups == default ? new Dictionary<IPhilote<IGDelegateGroup>, IGDelegateGroup>() : gDelegateGroups;
      GEnumerations = gEnumerations == default ? new Dictionary<IPhilote<IGEnumeration>, IGEnumeration>() : gEnumerations;
      GEnumerationGroups = gEnumerationGroups == default ? new Dictionary<IPhilote<IGEnumerationGroup>, IGEnumerationGroup>() : gEnumerationGroups;
      //GEnumerations = gEnumerations;
      //GExceptions = gExceptions;
      GComment = gComment == default ? new GComment() : gComment;
      Philote = new Philote<IGNamespace>();
    }

    public string GName { get; init; }
    public IDictionary<IPhilote<IGClass>, IGClass> GClasss { get; init; }
    public IDictionary<IPhilote<IGInterface>, IGInterface> GInterfaces { get; init; }
    public IDictionary<IPhilote<IGDelegate>, IGDelegate> GDelegates { get; init; }
    public IDictionary<IPhilote<IGDelegateGroup>, IGDelegateGroup> GDelegateGroups { get; init; }
    public IDictionary<IPhilote<IGEnumeration>, IGEnumeration> GEnumerations { get; init; }
    public IDictionary<IPhilote<IGEnumerationGroup>, IGEnumerationGroup> GEnumerationGroups { get; init; }
    //public IDictionary<IPhilote<IGException>, IGException>? GExceptions { get; init; }
    public IGComment GComment { get; init; }
    public IPhilote<IGNamespace> Philote { get; init; }

  }
}
