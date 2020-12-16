
using System;
using System.Collections.Generic;
using System.Text;

using ATAP.Utilities.Philote;
namespace GenerateProgram {
  public class GSolutionSignil  : IGSolutionSignil {
    public GSolutionSignil(bool hasPropsAndTargets
    , bool hasEditorConfig = default
    , bool hasArtefacts = default
    , bool hasDevLog = default
    , bool hasDocumentation = default
    , string sourceRelativePath = default
    , string testsRelativePath = default
    , bool hasOmniSharpConfiguration = default
    , bool hasVisualStudioCodeWorkspaceConfiguration = default
    , bool hasVisualStudioIISApplicationHostConfiguration = default
    , bool hasDataBases = default
    , ICollection<string> buildConfigurations = default
    , ICollection<string> cPUConfigurations = default
    , Dictionary<Philote<GProjectUnit>, GProjectUnit> gDependencyPackages = default
    , Dictionary<Philote<GProjectUnit>, GProjectUnit> gDependencyProjects = default
    , GComment gComment = default
    , GPatternReplacement gPatternReplacement = default
) {
      HasPropsAndTargets = hasPropsAndTargets == default ? false : hasPropsAndTargets;
      HasEditorConfig = hasEditorConfig == default ? false : hasEditorConfig;
      HasArtefacts = hasArtefacts == default ? false : hasArtefacts;
      HasDevLog = hasDevLog == default ? false : hasDevLog;
      HasDocumentation = hasDocumentation == default ? false : hasDocumentation;
      SourceRelativePath = sourceRelativePath == default ? "" : sourceRelativePath;
      TestsRelativePath = testsRelativePath == default ? "" : testsRelativePath;
      HasOmniSharpConfiguration = hasOmniSharpConfiguration == default ? false : hasOmniSharpConfiguration;
      HasVisualStudioCodeWorkspaceConfiguration = hasVisualStudioCodeWorkspaceConfiguration == default ? false : hasVisualStudioCodeWorkspaceConfiguration;
      HasVisualStudioIISApplicationHostConfiguration = hasVisualStudioIISApplicationHostConfiguration == default ? false : hasVisualStudioIISApplicationHostConfiguration;
      HasDataBases = hasDataBases == default ? false : hasDataBases;
      BuildConfigurations = buildConfigurations ?? throw new ArgumentNullException(nameof(buildConfigurations));
      CPUConfigurations = cPUConfigurations ?? throw new ArgumentNullException(nameof(cPUConfigurations));
      GComment = gComment == default ? new GComment() : gComment;
      GPatternReplacement = gPatternReplacement == default ? new GPatternReplacement() : gPatternReplacement;
      GDependencyPackages = gDependencyPackages ?? throw new ArgumentNullException(nameof(gDependencyPackages));
      GDependencyProjects = gDependencyProjects ?? throw new ArgumentNullException(nameof(gDependencyProjects));
      Philote = new Philote<GSolutionSignil>();
    }
    public bool HasPropsAndTargets { get; }
    public bool HasEditorConfig { get; }
    public bool HasArtefacts { get; }
    public bool HasDevLog { get; }
    public bool HasDocumentation { get; }
    public string SourceRelativePath { get; }
    public string TestsRelativePath { get; }
    public bool HasOmniSharpConfiguration { get; }
    public bool HasVisualStudioCodeWorkspaceConfiguration { get; }
    public bool HasVisualStudioIISApplicationHostConfiguration { get; }
    public bool HasDataBases { get; }
    public ICollection<string> BuildConfigurations { get; }
    public ICollection<string> CPUConfigurations { get; }
    public Dictionary<Philote<GProjectUnit>, GProjectUnit> GDependencyPackages { get; }
    public Dictionary<Philote<GProjectUnit>, GProjectUnit> GDependencyProjects { get; }
    public GPatternReplacement GPatternReplacement { get; }
    public GComment GComment { get; }
    public Philote<GSolutionSignil> Philote { get; }
  }
}
