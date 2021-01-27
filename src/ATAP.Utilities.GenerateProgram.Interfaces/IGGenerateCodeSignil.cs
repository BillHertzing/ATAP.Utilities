using System;
using System.Threading;

using ATAP.Utilities.Persistence;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public interface IGGenerateCodeSignil {
    IGAssemblyGroupSignil? GAssemblyGroupSignil { get; set; }
    //IGGlobalSettingsSignil? GGlobalSettingsSignil { get; set; }
    IGSolutionSignil? GSolutionSignil { get; set; }
    string ArtifactsDirectoryBase { get; set; }
    string ArtifactsFileRelativePath { get; set; }
    string[] ArtifactsFilePaths { get; set; }
    string TemporaryDirectoryBase { get; set; }
    bool EnableProgress { get; set; }
    bool EnablePersistence { get; set; }
    bool EnablePickAndSave { get; set; }
    IGGenerateCodeProgress? Progress { get; set; }
    IPersistence<IInsertResultsAbstract>? Persistence { get; set; }
    IPickAndSave<IInsertResultsAbstract>? PickAndSave { get; set; }
    IEntryPoints EntryPoints { get; set; }
     CancellationToken CancellationTokenFromCaller { get; set; }
    IPhilote<IGGenerateCodeSignil> Philote { get; init; }
  }

}
