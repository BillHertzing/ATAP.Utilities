using System;
using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {

  public class GNamespace : IGNamespace {
    public GNamespace(string gName = "", Dictionary<IPhilote<IGClass>, IGClass>? gClasss = default,
      Dictionary<IPhilote<IGInterface>, IGInterface>? gInterfaces = default,
      Dictionary<IPhilote<IGDelegate>, IGDelegate>? gDelegates = default,
      Dictionary<IPhilote<IGDelegateGroup>, IGDelegateGroup>? gDelegateGroups = default,
      Dictionary<IPhilote<IGEnumeration>, IGEnumeration>? gEnumerations = default,
      Dictionary<IPhilote<IGEnumerationGroup>, IGEnumerationGroup>? gEnumerationGroups = default,
      //Dictionary<IPhilote<IGEnumeration>, IGEnumeration>? gEnumerations = default,
      //Dictionary<IPhilote<IGException>, IGException>? gExceptions = default
      IGComment gComment = default

      ) {
      GName = gName;
      GClasss = gClasss == default ? new Dictionary<Philote<GClass>, GClass>() : gClasss;
      GInterfaces = gInterfaces == default ? new Dictionary<Philote<GInterface>, GInterface>() : gInterfaces;
      GDelegates = gDelegates == default ? new Dictionary<Philote<GDelegate>, GDelegate>() : gDelegates;
      GDelegateGroups = gDelegateGroups == default ? new Dictionary<Philote<GDelegateGroup>, GDelegateGroup>() : gDelegateGroups;
      GEnumerations = gEnumerations == default ? new Dictionary<Philote<GEnumeration>, GEnumeration>() : gEnumerations;
      GEnumerationGroups = gEnumerationGroups == default ? new Dictionary<Philote<GEnumerationGroup>, GEnumerationGroup>() : gEnumerationGroups;
      //GEnumerations = gEnumerations;
      //GExceptions = gExceptions;
      GComment = gComment == default ? new GComment() : gComment;
      Philote = new Philote<GNamespace>();
    }

    public string GName { get; init; }
    public Dictionary<IPhilote<IGClass>, IGClass> GClasss { get; init; }
    public Dictionary<IPhilote<IGInterface>, IGInterface> GInterfaces { get; init; }
    public Dictionary<IPhilote<IGDelegate>, IGDelegate> GDelegates { get; init; }
    public Dictionary<IPhilote<IGDelegateGroup>, IGDelegateGroup> GDelegateGroups { get; init; }
    public Dictionary<IPhilote<IGEnumeration>, IGEnumeration> GEnumerations { get; init; }
    public Dictionary<IPhilote<IGEnumerationGroup>, IGEnumerationGroup> GEnumerationGroups { get; init; }
    //public Dictionary<IPhilote<IGException>, IGException>? GExceptions { get; init; }
    public IGComment GComment { get; init; }
    public IPhilote<IGNamespace> Philote { get; init; }

  }
}
