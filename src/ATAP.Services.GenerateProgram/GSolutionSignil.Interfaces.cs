using System;
using System.Collections.Generic;
namespace GenerateProgram {
  public class IGSolutionSignil {
    public bool HasPropsAndTargets { get; }
    public bool HasEditorCofig { get; }
    public bool HasArtefacts { get; }
    public bool HasDevLog { get; }
    public bool HasDocumentation { get; }
    string SourceRelativePath { get; }
    string TestsRelativePath { get; }
    public bool HasOmniSharpConfiguration { get; }
    public bool HasVisualStudioCodeWorkspaceConfiguration { get; }
    public bool HasVisualStudioIISApplicationHostConfiguration { get; }
    public bool HasDataBases { get; }
    public ICollection<string> BuildConfigurations { get; }
    public ICollection<string> CPUConfigurations { get; }
    public GPatternReplacement GPatternReplacement { get; }
    public GComment GComment { get; }

  }
}
