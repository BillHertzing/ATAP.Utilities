using System;
using System.Collections.Generic;
using System.Text;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public class GCompilationUnit {
    public GCompilationUnit(string gName, string gRelativePath=default, string gFileSuffix=default, Dictionary<Philote<GUsing>, GUsing> gUsings = default,
      Dictionary<Philote<GUsingGroup>, GUsingGroup> gUsingGroups = default,
      Dictionary<Philote<GNamespace>, GNamespace> gNamespaces = default) {
      GName = gName ?? throw new ArgumentNullException(nameof(gName));
      GRelativePath = gRelativePath == default ? "" : gRelativePath;
      GFileSuffix = gFileSuffix == default ? ".cs" : gFileSuffix;
      GUsings = gUsings == default ? new Dictionary<Philote<GUsing>, GUsing>() : gUsings;
      GUsingGroups = gUsingGroups == default ? new Dictionary<Philote<GUsingGroup>, GUsingGroup>() : gUsingGroups;
      GNamespaces = gNamespaces == default ? new Dictionary<Philote<GNamespace>, GNamespace>() : gNamespaces;
      Philote = new Philote<GCompilationUnit>();
    }

    public string GName { get; }
    public Dictionary<Philote<GUsingGroup>, GUsingGroup> GUsingGroups { get; }
    public Dictionary<Philote<GUsing>, GUsing> GUsings { get; }
    public Dictionary<Philote<GNamespace>, GNamespace> GNamespaces { get; }
    public string GRelativePath { get; }
    public string GFileSuffix { get; }
    public Philote<GCompilationUnit> Philote { get; }

  }
}

