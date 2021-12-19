
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
    , IGComment<TValue>? gComment = default
    , IGPatternReplacement<TValue>? gPatternReplacement = default
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
      GComment = gComment == default ? new GComment<TValue>() : gComment;
      GPatternReplacement = gPatternReplacement == default ? new GPatternReplacement<TValue>() : gPatternReplacement;
      GDependencyPackages = gDependencyPackages ?? throw new ArgumentNullException(nameof(gDependencyPackages));
      GDependencyProjects = gDependencyProjects ?? throw new ArgumentNullException(nameof(gDependencyProjects));
      Id = new GSolutionSignilId<TValue>();
    }
    public bool HasPropsAndTargets { get; init; }
    public bool HasEditorConfig { get; init; }
    public bool HasArtifacts { get; init; }
    public bool HasDevLog { get;init;  }
    public bool HasDocumentation { get; init; }
    public string SourceRelativePath { get;init;  }
    public string TestsRelativePath { get; init; }
    public bool HasOmniSharpConfiguration { get; init; }
    public bool HasVisualStudioCodeWorkspaceConfiguration { get; init; }
    public bool HasVisualStudioIISApplicationHostConfiguration { get; init; }
    public bool HasDataBases { get;init;  }
    public ICollection<string> BuildConfigurations { get; init; }
    public ICollection<string> CPUConfigurations { get; init; }
    public IDictionary<IGProjectUnitId<TValue>, IGProjectUnit<TValue>>? GDependencyPackages { get; init; }
    public IDictionary<IGProjectUnitId<TValue>, IGProjectUnit<TValue>>? GDependencyProjects { get; init; }
    public IGPatternReplacement<TValue>? GPatternReplacement { get; init; }
    public IGComment<TValue>? GComment { get;init;  }
    public  IGSolutionSignilId<TValue> Id { get; init; }
  }
}






