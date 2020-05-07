using System;
using System.Collections.Generic;
using System.Text;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public class GInterface {
    public GInterface(string gName,
      Dictionary<Philote<GProperty>, GProperty> gPropertys = default,
      Dictionary<Philote<GPropertyGroup>, GPropertyGroup> gPropertyGroups = default,

      Dictionary<Philote<GMethod>, GMethod> gMethods = default,
    Dictionary<Philote<GMethodGroup>, GMethodGroup> gMethodGroups = default
    //Dictionary<Philote<GException>, GException> gExceptions = default,
    //  Dictionary<Philote<GExceptionGroup>, GExceptionGroup> gExceptionGroups = default,
    //Dictionary<Philote<GEvent>, GEvent> gEvents = default,
    //  Dictionary<Philote<GEventGroup>, GEventGroup> gEventGroups = default,
      ) {
      GName = gName ?? throw new ArgumentNullException(nameof(gName));
      GPropertys = gPropertys  == default? new Dictionary<Philote<GProperty>, GProperty>() : gPropertys;
      GPropertyGroups = gPropertyGroups == default ? new Dictionary<Philote<GPropertyGroup>, GPropertyGroup>() : gPropertyGroups;
      GMethods = gMethods  == default? new Dictionary<Philote<GMethod>, GMethod>() : gMethods;
      GMethodGroups = gMethodGroups == default ? new Dictionary<Philote<GMethodGroup>, GMethodGroup>() : gMethodGroups;
      //GExceptions = gExceptions  == default? new Dictionary<Philote<GException>, GException>() : gExceptions;
      //GExceptionGroups = gExceptionGroups == default ? new Dictionary<Philote<GExceptionGroup>, GExceptionGroup>() : gExceptionGroups;
      //GEvents = gEvents  == default? new Dictionary<Philote<GEvent>, GEvent>() : gEvents;
      //GEventGroups = gEventGroups == default ? new Dictionary<Philote<GEventGroup>, GEventGroup>() : gEventGroups;

      Philote = new Philote<GInterface>();
    }
    public string GName { get; }
    public Dictionary<Philote<GProperty>, GProperty> GPropertys { get; }
    public Dictionary<Philote<GPropertyGroup>, GPropertyGroup> GPropertyGroups { get; }
    public Dictionary<Philote<GMethod>, GMethod> GMethods { get; }
    public Dictionary<Philote<GMethodGroup>, GMethodGroup> GMethodGroups { get; }
    //public Dictionary<Philote<GException>, GException> GExceptions { get; }
    //public Dictionary<Philote<GExceptionGroup>, GExceptionGroup> GExceptionGroups { get; }
    //public Dictionary<Philote<GEvent>, GEvent> GEvents { get; }
    //public Dictionary<Philote<GEventGroup>, GEventGroup> GEventGroups { get; }
    public Philote<GInterface> Philote { get; }
  }
}

