using System;
using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public class GNamespace {
    public GNamespace(string gName, Dictionary<Philote<GClass>, GClass>? gClasss = default,
      Dictionary<Philote<GInterface>, GInterface>? gInterfaces = default
      //Dictionary<Philote<GEnumeration>, GEnumeration>? gEnumerations = default,
      //Dictionary<Philote<GException>, GException>? gExceptions = default
      ) {
      GName = gName ?? throw new ArgumentNullException(nameof(gName));
      GClasss = gClasss == default ? new Dictionary<Philote<GClass>, GClass>() : gClasss;
      GInterfaces = gInterfaces == default? new Dictionary<Philote<GInterface>, GInterface>() : gInterfaces;

      //GEnumerations = gEnumerations;
      //GExceptions = gExceptions;
      Philote = new Philote<GNamespace>();
    }




    public string GName { get; }
    public Dictionary<Philote<GClass>, GClass> GClasss { get; }
    public Dictionary<Philote<GInterface>, GInterface>? GInterfaces { get; }
    //public Dictionary<Philote<GException>, GException>? GExceptions { get; }
    //public Dictionary<Philote<GEnumeration>, GEnumeration>? GEnumerations { get; }
    public Philote<GNamespace> Philote { get; }

  }
}
