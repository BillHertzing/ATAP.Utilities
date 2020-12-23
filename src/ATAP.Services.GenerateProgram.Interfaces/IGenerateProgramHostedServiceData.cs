using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Localization;
using Microsoft.Extensions.Logging;

using ATAP.Utilities.ETW;
using ATAP.Utilities.GenerateProgram;
namespace ATAP.Services.HostedService.GenerateProgram {
  public interface IGenerateProgramHostedServiceData : IDisposable {
    IList<(IGInvokeGenerateCodeSignil, IGGenerateProgramResult)> GenerateCodeTasks { get; init; }

    void Dispose();
  }
}
