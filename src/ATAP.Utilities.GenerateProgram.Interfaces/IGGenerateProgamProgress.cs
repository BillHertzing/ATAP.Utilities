using System;
using ATAP.Utilities.Philote;
namespace ATAP.Utilities.GenerateProgram {
  public interface IGGenerateCodeProgressReport : IProgress<string> {
  
    IPhilote<IGGenerateCodeProgressReport> Philote { get; init; }
  }
}