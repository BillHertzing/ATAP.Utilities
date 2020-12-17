using System;
using System.Collections.Generic;

using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public class GInterface : IGInterface {
    public GInterface(string gName, string gVisibility = default, string gAccessModifier = default, string gInheritance = default,
      IList<string> gImplements = default,
      Dictionary<IPhilote<IGProperty>, IGProperty> gPropertys = default,
      Dictionary<IPhilote<IGPropertyGroup>, IGPropertyGroup> gPropertyGroups = default,

      Dictionary<IPhilote<IGMethod>, IGMethod> gMethods = default,
    Dictionary<IPhilote<IGMethodGroup>, IGMethodGroup> gMethodGroups = default
    //Dictionary<IPhilote<IGException>, IGException> gExceptions = default,
    //  Dictionary<IPhilote<IGExceptionGroup>, IGExceptionGroup> gExceptionGroups = default,
    //Dictionary<IPhilote<IGEvent>, IGEvent> gEvents = default,
    //  Dictionary<IPhilote<IGEventGroup>, IGEventGroup> gEventGroups = default,
      ) {
      GName = gName ?? throw new ArgumentNullException(nameof(gName));
      GVisibility = gVisibility == default ? "" : gVisibility; ;
      GAccessModifier = gAccessModifier == default ? "" : gAccessModifier;
      GInheritance = gInheritance == default ? "" : gInheritance; ;
      GImplements = gImplements == default ? new List<string>() : gImplements;
      GPropertys = gPropertys == default ? new Dictionary<Philote<GProperty>, GProperty>() : gPropertys;
      GPropertyGroups = gPropertyGroups == default ? new Dictionary<Philote<GPropertyGroup>, GPropertyGroup>() : gPropertyGroups;
      GMethods = gMethods == default ? new Dictionary<Philote<GMethod>, GMethod>() : gMethods;
      GMethodGroups = gMethodGroups == default ? new Dictionary<Philote<GMethodGroup>, GMethodGroup>() : gMethodGroups;
      //GExceptions = gExceptions  == default? new Dictionary<Philote<GException>, GException>() : gExceptions;
      //GExceptionGroups = gExceptionGroups == default ? new Dictionary<Philote<GExceptionGroup>, GExceptionGroup>() : gExceptionGroups;
      //GEvents = gEvents  == default? new Dictionary<Philote<GEvent>, GEvent>() : gEvents;
      //GEventGroups = gEventGroups == default ? new Dictionary<Philote<GEventGroup>, GEventGroup>() : gEventGroups;

      Philote = new Philote<GInterface>();
    }
    public string GName { get; }
    public string GVisibility { get; }
    // ToDo: make this an enumeration
    public string GAccessModifier { get; }
    public string GInheritance { get; }
    public IList<string> GImplements { get; }
    public Dictionary<IPhilote<IGProperty>, IGProperty> GPropertys { get; }
    public Dictionary<IPhilote<IGPropertyGroup>, IGPropertyGroup> GPropertyGroups { get; }
    public Dictionary<IPhilote<IGMethod>, IGMethod> GMethods { get; }
    public Dictionary<IPhilote<IGMethodGroup>, IGMethodGroup> GMethodGroups { get; }
    //public Dictionary<IPhilote<IGException>, IGException> GExceptions { get; }
    //public Dictionary<IPhilote<IGExceptionGroup>, IGExceptionGroup> GExceptionGroups { get; }
    //public Dictionary<IPhilote<IGEvent>, IGEvent> GEvents { get; }
    //public Dictionary<IPhilote<IGEventGroup>, IGEventGroup> GEventGroups { get; }
    public IPhilote<IGInterface> Philote { get; }
  }
}

