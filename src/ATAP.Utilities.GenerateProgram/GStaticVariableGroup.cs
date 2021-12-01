using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {

  public record GStaticVariableGroupId<TValue> : AbstractStronglyTypedId<TValue>, IGStaticVariableGroupId<TValue> where TValue : notnull {}
  public class GStaticVariableGroup<TValue> : IGStaticVariableGroup<TValue> where TValue : notnull {
    public GStaticVariableGroup(string gName = default, IDictionary<IGStaticVariableId<TValue>, IGStaticVariable<TValue>> gStaticVariables = default) {
      GName = gName == default ? "" : gName;
      GStaticVariables = gStaticVariables == default ? new Dictionary<IGStaticVariableId<TValue>, IGStaticVariable<TValue>>() : gStaticVariables;
      Id = new GStaticVariableGroupId<TValue>();
    }

    public string GName { get; init; }
    public IDictionary<IGStaticVariableId<TValue>, IGStaticVariable<TValue>> GStaticVariables { get; init; }
    public  IGStaticVariableGroupId Id { get; init; }
  }
}






