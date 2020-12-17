using System;
using System.Collections.Generic;

using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public class GInterface : IGInterface {
    public GInterface(string gName, string gVisibility = default, string gAccessModifier = default, string gInheritance = default,
      IList<string> gImplements = default,
      IDictionary<IPhilote<IGProperty>, IGProperty> gPropertys = default,
      IDictionary<IPhilote<IGPropertyGroup>, IGPropertyGroup> gPropertyGroups = default,
      IDictionary<IPhilote<IGMethod>, IGMethod> gMethods = default,
      IDictionary<IPhilote<IGMethodGroup>, IGMethodGroup> gMethodGroups = default
      //IDictionary<IPhilote<IGException>, IGException> gExceptions = default,
      //IDictionary<IPhilote<IGExceptionGroup>, IGExceptionGroup> gExceptionGroups = default,
      //IDictionary<IPhilote<IGEvent>, IGEvent> gEvents = default,
      //IDictionary<IPhilote<IGEventGroup>, IGEventGroup> gEventGroups = default,
      ) {
      GName = gName ?? throw new ArgumentNullException(nameof(gName));
      GVisibility = gVisibility == default ? "" : gVisibility; ;
      GAccessModifier = gAccessModifier == default ? "" : gAccessModifier;
      GInheritance = gInheritance == default ? "" : gInheritance; ;
      GImplements = gImplements == default ? new List<string>() : gImplements;
      GPropertys = gPropertys == default ? new Dictionary<IPhilote<IGProperty>, IGProperty>() : gPropertys;
      GPropertyGroups = gPropertyGroups == default ? new Dictionary<IPhilote<IGPropertyGroup>, IGPropertyGroup>() : gPropertyGroups;
      GMethods = gMethods == default ? new Dictionary<IPhilote<IGMethod>, IGMethod>() : gMethods;
      GMethodGroups = gMethodGroups == default ? new Dictionary<IPhilote<IGMethodGroup>, IGMethodGroup>() : gMethodGroups;
      //GExceptions = gExceptions  == default? new Dictionary<IPhilote<IGException>, IGException>() : gExceptions;
      //GExceptionGroups = gExceptionGroups == default ? new Dictionary<IPhilote<IGExceptionGroup>, IGExceptionGroup>() : gExceptionGroups;
      //GEvents = gEvents  == default? new Dictionary<IPhilote<IGEvent>, IGEvent>() : gEvents;
      //GEventGroups = gEventGroups == default ? new Dictionary<IPhilote<IGEventGroup>, IGEventGroup>() : gEventGroups;

      Philote = new Philote<IGInterface>();
    }
    public string GName { get; }
    public string GVisibility { get; }
    // ToDo: make this an enumeration
    public string GAccessModifier { get; }
    public string GInheritance { get; }
    public IList<string> GImplements { get; }
    public IDictionary<IPhilote<IGProperty>, IGProperty> GPropertys { get; }
    public IDictionary<IPhilote<IGPropertyGroup>, IGPropertyGroup> GPropertyGroups { get; }
    public IDictionary<IPhilote<IGMethod>, IGMethod> GMethods { get; }
    public IDictionary<IPhilote<IGMethodGroup>, IGMethodGroup> GMethodGroups { get; }
    //public IDictionary<IPhilote<IGException>, IGException> GExceptions { get; }
    //public IDictionary<IPhilote<IGExceptionGroup>, IGExceptionGroup> GExceptionGroups { get; }
    //public IDictionary<IPhilote<IGEvent>, IGEvent> GEvents { get; }
    //public IDictionary<IPhilote<IGEventGroup>, IGEventGroup> GEventGroups { get; }
    public IPhilote<IGInterface> Philote { get; }
  }
}

