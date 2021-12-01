using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {

  public record GStaticVariableId<TValue> : AbstractStronglyTypedId<TValue>, IGStaticVariableId<TValue> where TValue : notnull {}
  public class GStaticVariable<TValue> : IGStaticVariable<TValue> where TValue : notnull {
    public GStaticVariable(string gName = default, string gType = default, string gVisibility = default, string gAccessModifier = default,
      IGBody gBody = default, IList<string> gAdditionalStatements = default, IGComment gComment = default) {
      GName = gName == default ? "" : gName;
      GVisibility = gVisibility == default ? "" : gVisibility;
      GType = gType == default ? "" : gType;
      GAccessModifier = gAccessModifier == default ? "" : gAccessModifier;
      GBody = gBody == default ? new GBody() : gBody;
      GAdditionalStatements = gAdditionalStatements == default ? new List<string>() : gAdditionalStatements;
      GComment = gComment == default ? new GComment() : gComment;
      Id = new GStaticVariableId<TValue>();
    }

    public string GName { get; init; }
    public string GType { get; init; }
    // ToDo: make this an enumeration
    public string GAccessModifier { get; init; }
    public string GVisibility { get; init; }
    public IGBody GBody { get; init; }
    public IList<string> GAdditionalStatements { get; init; }
    public IGComment GComment { get; init; }
    public  IGStaticVariableId Id { get; init; }
  }
}






