using System;
using ATAP.Utilities.ETW;
using ATAP.Utilities.Persistence;
using ATAP.Utilities.Philote;
using ATAP.Utilities.GenerateProgram;

namespace ATAP.Services.GenerateCode {

  public partial class GInvokeGenerateCodeSignil : GGenerateCodeSignil, IGInvokeGenerateCodeSignil {
    public string PersistenceMessageFileRelativePath { get; }
    public string[] PersistenceFilePaths { get; }
    public string PickAndSaveMessageFileRelativePath { get; }
    public string[] PickAndSaveFilePaths { get; }
    public string DBConnectionString { get; }
    public string OrmLiteDialectProviderStringDefault { get; }

    public new IPhilote<IGInvokeGenerateCodeSignil> Philote {get; }
    public GInvokeGenerateCodeSignil(
      IGAssemblyGroupSignil? gAssemblyGroupSignil = default
     // , IGGlobalSettingsSignil? gGlobalSettingsSignil = default
      , IGSolutionSignil? gSolutionSignil = default
      , string artifactsDirectoryBase = default
      , string artifactsFileRelativePath = default
      , string[] artifactsFilePaths = default
      , string temporaryDirectoryBase = default
      , bool enableProgress = default
      , bool enablePersistence = default
      , bool enablePickAndSave = default
      , string persistenceMessageFileRelativePath = default
      , string[] persistenceFilePaths = default
      , string pickAndSaveMessageFileRelativePath = default
      , string[] pickAndSaveFilePaths = default
      , IGGenerateCodeProgress? progress = default
      , IPersistence<IInsertResultsAbstract>? persistence = default
      , IPickAndSave<IInsertResultsAbstract>? pickAndSave = default
      , string dBConnectionString = default
      , string ormLiteDialectProviderStringDefault = default
      , IEntryPoints entryPoints = default
      ) {
      // ToDo: use the ATAP normal method of parameter->Property settings
      GAssemblyGroupSignil = gAssemblyGroupSignil;
      //GGlobalSettingsSignil = gGlobalSettingsSignil;
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

      PersistenceMessageFileRelativePath = persistenceMessageFileRelativePath;
      PersistenceFilePaths = persistenceFilePaths;
      PickAndSaveMessageFileRelativePath = pickAndSaveMessageFileRelativePath;
      PickAndSaveFilePaths = pickAndSaveFilePaths;
      DBConnectionString = dBConnectionString;
      OrmLiteDialectProviderStringDefault = ormLiteDialectProviderStringDefault;
      Philote = new Philote<IGInvokeGenerateCodeSignil>();
    }
  }

}
