using System;
using System.Threading;

using ATAP.Utilities.ETW;
using ATAP.Utilities.Persistence;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {
#if TRACE
  [ETWLogAttribute]
#endif
  public partial class GGenerateCodeSignil : IGGenerateCodeSignil {
    public IGAssemblyGroupSignil? GAssemblyGroupSignil { get; set; }
    //public IGGlobalSettingsSignil? GGlobalSettingsSignil { get; set; }
    public IGSolutionSignil? GSolutionSignil { get; set; }
    public string ArtifactsDirectoryBase { get; set; }
    public string ArtifactsFileRelativePath { get; set; }
    public string[] ArtifactsFilePaths { get; set; }
    public string TemporaryDirectoryBase { get; set; }
    public bool EnableProgress { get; set; }
    public bool EnablePersistence { get; set; }
    public bool EnablePickAndSave { get; set; }
    public IGGenerateCodeProgress? Progress { get; set; }
    public IPersistence<IInsertResultsAbstract>? Persistence { get; set; }
    public IPickAndSave<IInsertResultsAbstract>? PickAndSave { get; set; }
    public IEntryPoints EntryPoints { get; set; }
    public CancellationToken CancellationTokenFromCaller { get; set; }
    public  IGGenerateCodeSignilId Id { get; init; }
    public GGenerateCodeSignil(
      IGAssemblyGroupSignil? gAssemblyGroupSignil = default
      //, IGGlobalSettingsSignil? gGlobalSettingsSignil = default
      , IGSolutionSignil? gSolutionSignil = default
      , string artifactsDirectoryBase = default
      , string artifactsFileRelativePath = default
      , string[] artifactsFilePaths = default
      , string temporaryDirectoryBase = default
      , bool enableProgress = default
      , bool enablePersistence = default
      , bool enablePickAndSave = default
      , IGGenerateCodeProgress? progress = default
      , IPersistence<IInsertResultsAbstract>? persistence = default
      , IPickAndSave<IInsertResultsAbstract>? pickAndSave = default
      , IEntryPoints entryPoints = default
            , CancellationToken cancellationTokenFromCaller = default
) {
      // ToDo: use the ATAP normal method of parameter->Property settings
      GAssemblyGroupSignil = gAssemblyGroupSignil;
     // GGlobalSettingsSignil = gGlobalSettingsSignil;
      GSolutionSignil = gSolutionSignil;
      ArtifactsDirectoryBase = artifactsDirectoryBase;
      ArtifactsFileRelativePath = artifactsFileRelativePath;
      ArtifactsFilePaths = artifactsFilePaths;
      TemporaryDirectoryBase = temporaryDirectoryBase;
      EnableProgress = enableProgress;
      EnablePersistence = enablePersistence;
      EnablePickAndSave = enablePickAndSave;
      Progress = progress;
      Persistence = persistence;
      PickAndSave = pickAndSave;
      EntryPoints = entryPoints;
      CancellationTokenFromCaller = cancellationTokenFromCaller;
      Id = new IGGenerateCodeSignilId<TValue>();
    }
  }

}






