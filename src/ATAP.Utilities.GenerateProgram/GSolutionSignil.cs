
using System;
using System.Collections.Generic;
using System.Text;

using ATAP.Utilities.StronglyTypedId;
namespace ATAP.Utilities.GenerateProgram {

  public record GSolutionSignilId<TValue> : AbstractStronglyTypedId<TValue>, IGSolutionSignilId<TValue> where TValue : notnull {}
  public class GSolutionSignil<TValue> : IGSolutionSignil<TValue> where TValue : notnull {
    public GSolutionSignil(
      bool hasPropsAndTargets = default
    , bool hasEditorConfig = default
    , bool hasArtifacts = default
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
    , IDictionary<IGProjectUnitId<TValue>, IGProjectUnit<TValue>> gDependencyPackages = default
    , IDictionary<IGProjectUnitId<TValue>, IGProjectUnit<TValue>> gDependencyProjects = default
    , IGComment gComment = default
    , IGPatternReplacement gPatternReplacement = default
) {
      HasPropsAndTargets = hasPropsAndTargets == default ? false : hasPropsAndTargets;
      HasEditorConfig = hasEditorConfig == default ? false : hasEditorConfig;
      HasArtifacts = hasArtifacts == default ? false : hasArtifacts;
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
      Id = new GSolutionSignilId<TValue>();
    }
    public bool HasPropsAndTargets { get; }
    public bool HasEditorConfig { get; }
    public bool HasArtifacts { get; }
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
    public IDictionary<IGProjectUnitId<TValue>, IGProjectUnit<TValue>> GDependencyPackages { get; }
    public IDictionary<IGProjectUnitId<TValue>, IGProjectUnit<TValue>> GDependencyProjects { get; }
    public IGPatternReplacement GPatternReplacement { get; }
    public IGComment GComment { get; }
    public  IGSolutionSignilId Id { get; }
  }
}






