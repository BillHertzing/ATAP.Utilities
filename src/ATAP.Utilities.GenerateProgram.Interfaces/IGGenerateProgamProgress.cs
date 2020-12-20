using System;

using ATAP.Utilities.Philote;
namespace ATAP.Utilities.GenerateProgram {
  public interface IGGenerateProgramProgress : IProgress<string> {
    IPhilote<IGGenerateProgramProgress> Philote { get; init; }
  }
}
