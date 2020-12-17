using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {

  public class GStaticVariable : IGStaticVariable {
    public GStaticVariable(string gName = default, string gType = default, string gVisibility = default, string gAccessModifier = default,
      IGBody gBody = default, IList<string> gAdditionalStatements = default, IGComment gComment = default) {
      GName = gName == default ? "" : gName;
      GVisibility = gVisibility == default ? "" : gVisibility;
      GType = gType == default ? "" : gType;
      GAccessModifier = gAccessModifier == default ? "" : gAccessModifier;
      GBody = gBody == default ? new GBody() : gBody;
      GAdditionalStatements = gAdditionalStatements == default ? new List<string>() : gAdditionalStatements;
      GComment = gComment == default ? new GComment() : gComment;
      Philote = new Philote<GStaticVariable>();
    }

    public string GName { get; init; }
    public string GType { get; init; }
    // ToDo: make this an enumeration
    public string GAccessModifier { get; init; }
    public string GVisibility { get; init; }
    public IGBody GBody { get; init; }
    public IList<string> GAdditionalStatements { get; init; }
    public IGComment GComment { get; init; }
    public IPhilote<IGStaticVariable> Philote { get; init; }
  }
}
