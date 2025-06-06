using System;
using System.Collections.Generic;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Localization;
using Microsoft.Extensions.Logging;
using ATAP.Utilities.Philote;
using ATAP.Utilities.GenerateProgram;

namespace ATAP.Services.GenerateCode {



  public partial class GenerateProgramHostedServiceData : IGenerateProgramHostedServiceData {

    public IDictionary<IPhilote<IGInvokeGenerateCodeSignil>,Task<IGGenerateProgramResult>>  GenerateCodeTasks { get; set; }

    public GenerateProgramHostedServiceData() {
      GenerateCodeTasks = new Dictionary<IPhilote<IGInvokeGenerateCodeSignil>,Task<IGGenerateProgramResult>>();
    }

    #region IDisposable Support
    // ToDo: this should be the count of dictionary elements whose value (Task) is not Task.Completed or Task.Faulted (maybe Task.Running?)
    private int NonDisposedCount { get => GenerateCodeTasks.Count;  }

    private bool disposedValue = false; // To detect redundant calls

    protected virtual void Dispose(bool disposing) {
      if (!disposedValue) {
        if (disposing) {
          // Loop over every dictionary entry, cancelling any that are running,
          // ToDo: expand this safely cancel any running tasks and dispose of any resources they hold
          // foreach (var value in GenerateCodeTasks.Values) { value.Dispose(); }
          GC.SuppressFinalize(this);
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
