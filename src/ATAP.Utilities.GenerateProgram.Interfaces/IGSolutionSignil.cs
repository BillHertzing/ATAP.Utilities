using System;
using System.Collections.Generic;
namespace ATAP.Utilities.GenerateProgram {
  public class IGSolutionSignil {
    public bool HasPropsAndTargets { get; init; }
    public bool HasEditorCofig { get; init; }
    public bool HasArtefacts { get; init; }
    public bool HasDevLog { get; init; }
    public bool HasDocumentation { get; init; }
    string SourceRelativePath { get; init; }
    string TestsRelativePath { get; init; }
    public bool HasOmniSharpConfiguration { get; init; }
    public bool HasVisualStudioCodeWorkspaceConfiguration { get; init; }
    public bool HasVisualStudioIISApplicationHostConfiguration { get; init; }
    public bool HasDataBases { get; init; }
    public ICollection<string> BuildConfigurations { get; init; }
    public ICollection<string> CPUConfigurations { get; init; }
    public IGPatternReplacement GPatternReplacement { get; init; }
    public IGComment GComment { get; init; }

  }
}
