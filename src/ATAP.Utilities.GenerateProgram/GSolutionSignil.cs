
using System;
using System.Collections.Generic;
using System.Text;

using ATAP.Utilities.Philote;
namespace ATAP.Utilities.GenerateProgram {
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
    , IDictionary<IPhilote<IGProjectUnit>, IGProjectUnit> gDependencyPackages = default
    , IDictionary<IPhilote<IGProjectUnit>, IGProjectUnit> gDependencyProjects = default
    , IGComment gComment = default
    , IGPatternReplacement gPatternReplacement = default
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
      Philote = new Philote<IGSolutionSignil>();
    }
    public bool HasPropsAndTargets { get; init; }
    public bool HasEditorConfig { get; init; }
    public bool HasArtefacts { get; init; }
    public bool HasDevLog { get; init; }
    public bool HasDocumentation { get; init; }
    public string SourceRelativePath { get; init; }
    public string TestsRelativePath { get; init; }
    public bool HasOmniSharpConfiguration { get; init; }
    public bool HasVisualStudioCodeWorkspaceConfiguration { get; init; }
    public bool HasVisualStudioIISApplicationHostConfiguration { get; init; }
    public bool HasDataBases { get; init; }
    public ICollection<string> BuildConfigurations { get; init; }
    public ICollection<string> CPUConfigurations { get; init; }
    public IDictionary<IPhilote<IGProjectUnit>, IGProjectUnit> GDependencyPackages { get; init; }
    public IDictionary<IPhilote<IGProjectUnit>, IGProjectUnit> GDependencyProjects { get; init; }
    public IGPatternReplacement GPatternReplacement { get; init; }
    public IGComment GComment { get; init; }
    public IPhilote<IGSolutionSignil> Philote { get; init; }
  }
}
