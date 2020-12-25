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
using ATAP.Utilities.Philote;
namespace ATAP.Services.GenerateCode {
  public interface IGenerateProgramHostedServiceData : IDisposable {
    IDictionary<IPhilote<IGInvokeGenerateCodeSignil>,IGGenerateProgramResult> GenerateCodeTasks { get; init; }

    void Dispose();
  }
}
