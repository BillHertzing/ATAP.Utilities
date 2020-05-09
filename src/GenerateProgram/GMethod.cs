using System;
using System.Collections.Generic;
using System.Text;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public class GMethod {
    public GMethod( GMethodDeclaration gDeclaration = default, GStatementList gBody = default, GComment gComment = default) {
      GDeclaration = gDeclaration == default? new GMethodDeclaration() : gDeclaration;
      GBody = gBody == default? new GStatementList() : gBody;
      GComment = gComment == default? new GComment() : gComment;
      Philote = new Philote<GMethod>();
    }

    public GMethodDeclaration GDeclaration { get; }
    public GStatementList GBody { get; }
    public GComment GComment { get; }
    public Philote<GMethod> Philote { get; }
  }
}

