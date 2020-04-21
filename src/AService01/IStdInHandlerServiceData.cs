using Microsoft.Extensions.Configuration;
using System;
using System.Collections.Generic;
using System.Text;

namespace ATAP.Utilities.HostedServices.StdInHandlerService {
  interface IStdInHandlerServiceData {
    IEnumerable<string> Choices { get; }
    ConfigurationRoot ConfigurationRoot { get; }
    StringBuilder Mesg { get; }
    StringBuilder StdInHandlerState { get; }
    IDisposable SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle { get; set; }

    void Dispose();
  }
}
