using System;
using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public class GNamespace {
    public GNamespace(string gName = "", Dictionary<Philote<GClass>, GClass>? gClasss = default,
      Dictionary<Philote<GInterface>, GInterface>? gInterfaces = default,
      Dictionary<Philote<GDelegate>, GDelegate>? gDelegates = default,
      Dictionary<Philote<GDelegateGroup>, GDelegateGroup>? gDelegateGroups = default,
      Dictionary<Philote<GEnumeration>, GEnumeration>? gEnumerations = default,
      Dictionary<Philote<GEnumerationGroup>, GEnumerationGroup>? gEnumerationGroups = default,
      //Dictionary<Philote<GEnumeration>, GEnumeration>? gEnumerations = default,
      //Dictionary<Philote<GException>, GException>? gExceptions = default
      GComment gComment = default

      ) {
      GName = gName;
      GClasss = gClasss == default ? new Dictionary<Philote<GClass>, GClass>() : gClasss;
      GInterfaces = gInterfaces == default? new Dictionary<Philote<GInterface>, GInterface>() : gInterfaces;
      GDelegates = gDelegates == default? new Dictionary<Philote<GDelegate>, GDelegate>() : gDelegates;
      GEnumerations = gEnumerations == default? new Dictionary<Philote<GEnumeration>, GEnumeration>() : gEnumerations;
      //GEnumerations = gEnumerations;
      //GExceptions = gExceptions;
      GComment = gComment == default? new GComment() : gComment;
      Philote = new Philote<GNamespace>();
    }

    public string GName { get; }
    public Dictionary<Philote<GClass>, GClass> GClasss { get; }
    public Dictionary<Philote<GInterface>, GInterface> GInterfaces { get; }
    public Dictionary<Philote<GDelegate>, GDelegate> GDelegates { get; }
    public Dictionary<Philote<GDelegateGroup>, GDelegateGroup> GDelegateGroups { get; }
    public Dictionary<Philote<GEnumeration>, GEnumeration> GEnumerations { get; }
    public Dictionary<Philote<GEnumerationGroup>, GEnumerationGroup> GEnumerationGroups { get; }
    //public Dictionary<Philote<GException>, GException>? GExceptions { get; }
    public GComment GComment { get; }
    public Philote<GNamespace> Philote { get; }

  }
}
