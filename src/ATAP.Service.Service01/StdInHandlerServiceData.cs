
using Microsoft.Extensions.Configuration;
using System;
using System.Collections.Generic;
using System.Text;

namespace ATAP.Utilities.HostedServices.StdInHandlerService {


  class StdInHandlerServiceData : IDisposable, IStdInHandlerServiceData {
    public ConfigurationRoot ConfigurationRoot { get; }
    public IEnumerable<string> Choices { get; }
    public StringBuilder Mesg { get; }
    public IDisposable SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle { get; set; }
    public StringBuilder StdInHandlerState { get; }

    public StdInHandlerServiceData(IEnumerable<string> choices, StringBuilder stdInHandlerState, StringBuilder mesg) {
      Choices = choices;
      StdInHandlerState = StdInHandlerState;
      Mesg = mesg;
    }

    #region IDisposable Support
    private bool disposedValue = false; // To detect redundant calls

    protected virtual void Dispose(bool disposing) {
      if (!disposedValue) {
        if (disposing) {
          if (SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle != null) {
            SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle.Dispose();
          }
        }
        disposedValue = true;
      }
    }

    // This code added to correctly implement the disposable pattern.
    public void Dispose() {
      // Do not change this code. Put cleanup code in Dispose(bool disposing) above.
      Dispose(true);
    }
    #endregion

  }
}
