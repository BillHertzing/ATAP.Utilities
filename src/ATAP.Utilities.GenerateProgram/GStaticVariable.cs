using System;
using System.Collections.Generic;
using System.Text;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public class GStaticVariable {
    public GStaticVariable(string gName = default, string gType = default, string gVisibility = default, string gAccessModifier = default,
      GBody gBody =default,List<string> gAdditionalStatements =default,  GComment gComment =default) {
      GName = gName == default ? "" : gName;
      GVisibility = gVisibility == default ? "" : gVisibility;
      GType = gType == default ? "" : gType;
      GAccessModifier = gAccessModifier == default ? "" : gAccessModifier;
      GBody = gBody == default? new GBody() : gBody;
      GAdditionalStatements = gAdditionalStatements == default? new List<string>() : gAdditionalStatements;
      GComment = gComment == default? new GComment() : gComment;
      Philote = new Philote<GStaticVariable>();
    }

    public string GName { get; }
    public string GType { get; }
    // ToDo: make this an enumeration
    public string GAccessModifier { get; }
    public string GVisibility { get; }
    public GBody GBody { get; }
    public List<string> GAdditionalStatements { get; }
    public GComment GComment { get; }
    public Philote<GStaticVariable> Philote { get; }
  }
}
