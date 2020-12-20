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

using ATAP.Utilities.GenerateProgram;

namespace ATAP.Services.HostedService.GenerateProgram {

#if TRACE
  [ETWLogAttribute]
#endif
  public partial class GenerateProgramHostedServiceData : IGenerateProgramHostedServiceData {

    public IGGenerateProgramResult GGenerateProgramResult { get; set; }

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
    public string DBConnectionString { get; set; }
    public string OrmLiteDialectProviderStringDefault { get; set; }
    public GenerateProgramHostedServiceData() {
      NonDisposedCount = 0;
    }

    #region IDisposable Support
    private int NonDisposedCount { get; set; }

    private bool disposedValue = false; // To detect redundant calls

    protected virtual void Dispose(bool disposing) {
      if (!disposedValue) {
        if (disposing) {
          this.Dispose();
        }

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
