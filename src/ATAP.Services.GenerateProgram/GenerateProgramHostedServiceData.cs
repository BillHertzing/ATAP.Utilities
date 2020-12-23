using System;
using System.Collections.Generic;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Localization;
using Microsoft.Extensions.Logging;

using ATAP.Utilities.ETW;
using ATAP.Utilities.Philote;
using ATAP.Utilities.Persistence;
using ATAP.Utilities.GenerateProgram;

namespace ATAP.Services.HostedService.GenerateProgram {

#if TRACE
  [ETWLogAttribute]
#endif
  public partial class GInvokeGenerateCodeSignil : IGInvokeGenerateCodeSignil {
    public IGAssemblyGroupSignil? GAssemblyGroupSignil { get; set; }
    public IGGlobalSettingsSignil? GGlobalSettingsSignil { get; set; }
    public IGSolutionSignil? GSolutionSignil { get; set; }
    public string ArtifactsDirectoryBase { get; set; }
    public string ArtifactsFileRelativePath { get; set; }
    public string[] ArtifactsFilePaths { get; set; }
    public bool EnablePersistence { get; set; }
    public bool EnablePickAndSave { get; set; }
    public bool EnableProgress { get; set; }
    public string TemporaryDirectoryBase { get; set; }
    public string PersistenceMessageFileRelativePath { get; set; }
    public string[] PersistenceFilePaths { get; set; }

    public string PickAndSaveMessageFileRelativePath { get; set; }
    public string[] PickAndSaveFilePaths { get; set; }
    IPersistence<IInsertResultsAbstract>? Persistence { get; set; }
    IPickAndSave<IInsertResultsAbstract>? PickAndSave { get; set; }
    public string DBConnectionString { get; set; }
    public string OrmLiteDialectProviderStringDefault { get; set; }
    public IEntryPoints EntryPoints { get; set; }
    public GInvokeGenerateCodeSignil(
      IGAssemblyGroupSignil? gAssemblyGroupSignil = default
      , IGGlobalSettingsSignil? gGlobalSettingsSignil = default
      , IGSolutionSignil? gSolutionSignil = default
      , string artifactsDirectoryBase = default
      , string artifactsFileRelativePath = default
      , string[] artifactsFilePaths = default
      , bool enablePersistence = default
      , bool enablePickAndSave = default
      , bool enableProgress = default
      , string temporaryDirectoryBase = default
      , string persistenceMessageFileRelativePath = default
      , string[] persistenceFilePaths = default
      , string pickAndSaveMessageFileRelativePath = default
      , string[] pickAndSaveFilePaths = default
      , IPersistence<IInsertResultsAbstract>? persistence = default
      , IPickAndSave<IInsertResultsAbstract>? pickAndSave = default
      , string dBConnectionString = default
      , string ormLiteDialectProviderStringDefault = default
      , IEntryPoints entryPoints = default
      ) {
      // ToDo: use the ATAP normal method of parameter->Property settings
      GAssemblyGroupSignil = gAssemblyGroupSignil;
      GGlobalSettingsSignil = gGlobalSettingsSignil;
      GSolutionSignil = gSolutionSignil;
      ArtifactsDirectoryBase = artifactsDirectoryBase;
      ArtifactsFileRelativePath = artifactsFileRelativePath;
      ArtifactsFilePaths = artifactsFilePaths;
      EnablePersistence = enablePersistence;
      EnablePickAndSave = enablePickAndSave;
      EnableProgress = enableProgress;
      TemporaryDirectoryBase = temporaryDirectoryBase;
      PersistenceMessageFileRelativePath = persistenceMessageFileRelativePath;
      PersistenceFilePaths = persistenceFilePaths;
      PickAndSaveMessageFileRelativePath = pickAndSaveMessageFileRelativePath;
      PickAndSaveFilePaths = pickAndSaveFilePaths;
      DBConnectionString = dBConnectionString;
      OrmLiteDialectProviderStringDefault = ormLiteDialectProviderStringDefault;
      EntryPoints = entryPoints;
      Persistence = persistence;
    }
  }



  public partial class GenerateProgramHostedServiceData : IGenerateProgramHostedServiceData {

    public IList<(IGInvokeGenerateCodeSignil, IGGenerateProgramResult)> GenerateCodeTasks { get; init; }

    public GenerateProgramHostedServiceData() {
      NonDisposedCount = 0;
      GenerateCodeTasks = new List<(IGInvokeGenerateCodeSignil, IGGenerateProgramResult)>();
    }

    #region IDisposable Support
    private int NonDisposedCount { get; set; }

    private bool disposedValue = false; // To detect redundant calls

    protected virtual void Dispose(bool disposing) {
      if (!disposedValue) {
        if (disposing) {
          this.Dispose();
        }
        // ToDo: Dispose each running task of the GenerateCodeTasks

        // TODO: free unmanaged resources (unmanaged objects) and override a finalizer below.
        // TODO: set large fields to null.

        disposedValue = true;
      }
    }

    // TODO: override a finalizer only if Dispose(bool disposing) above has code to free unmanaged resources.
    // ~ConvertFileSystemGraphToDBDataAndResults()
    // {
    //   // Do not change this code. Put cleanup code in Dispose(bool disposing) above.
    //   Dispose(false);
    // }

    // This code added to correctly implement the disposable pattern.
    public void Dispose() {
      // Do not change this code. Put cleanup code in Dispose(bool disposing) above.
      Dispose(true);
      // TODO: uncomment the following line if the finalizer is overridden above.
      // GC.SuppressFinalize(this);
    }
    #endregion


  }

}
