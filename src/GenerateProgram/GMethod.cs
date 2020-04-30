using System;
using System.Collections.Generic;
using System.Text;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public class GMethod {
    public GMethod( GMethodDeclaration gDeclaration, GMethodBody? gBody = default) {
      GDeclaration = gDeclaration ?? throw new ArgumentNullException(nameof(gDeclaration));
      GBody = gBody == default? new GMethodBody() : gBody;
      Philote = new Philote<GMethod>();
    }

    public GMethodDeclaration GDeclaration { get; }
    public GMethodBody GBody { get; }
    public Philote<GMethod> Philote { get; }
  }
}

