using System;
using System.Collections.Generic;
using System.Text;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public class GStaticVariable {
    public GStaticVariable(string gName = default, string gType = default, string gVisibility = default, string gAccessModifier = default,
      GStaticVariableBody gStaticVariableBody =default,GStatementList gAdditionalStatements =default,  GComment gComment =default) {
      GName = gName == default ? "" : gName;
      GVisibility = gVisibility == default ? "" : gVisibility;
      GType = gType == default ? "" : gType;
      GAccessModifier = gAccessModifier == default ? "" : gAccessModifier;
      GStaticVariableBody = gStaticVariableBody == default? new GStaticVariableBody() : gStaticVariableBody;
      GAdditionalStatements = gAdditionalStatements == default? new GStatementList() : gAdditionalStatements;
      GComment = gComment == default? new GComment() : gComment;
      Philote = new Philote<GStaticVariable>();
    }

    public string GName { get; }
    public string GType { get; }
    // ToDo: make this an enumeration
    public string GAccessModifier { get; }
    public string GVisibility { get; }
    public GStaticVariableBody GStaticVariableBody { get; }
    public GStatementList GAdditionalStatements { get; }
    public GComment GComment { get; }
    public Philote<GStaticVariable> Philote { get; }
  }
}
