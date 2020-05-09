using System;
using System.Collections.Generic;
using System.Management.Instrumentation;
using ATAP.Utilities.Philote;


namespace GenerateProgram {
  public class GDelegateDeclaration {
    public GDelegateDeclaration(string gName = default, string gType = default, string gVisibility = default, 
      Dictionary<Philote<GArgument>, GArgument> gArguments = default,
      GComment gComment = default) {
      GName = gName == default ? "" : gName;
      GVisibility = gVisibility == default ? "" : gVisibility;
      GType = gType == default ? "" : gType;
      GArguments = gArguments == default ? new Dictionary<Philote<GArgument>, GArgument>() : gArguments;
      GComment = gComment == default? new GComment() : gComment;
      Philote = new Philote<GDelegateDeclaration>();
    }
    public string GName { get; }
    public string GType { get; }
    // ToDo: make this an enumeration
    public string GVisibility { get; }
    public GComment GComment { get; }
    public Dictionary<Philote<GArgument>, GArgument> GArguments { get; }

    public Philote<GDelegateDeclaration> Philote { get; }

  }
}
