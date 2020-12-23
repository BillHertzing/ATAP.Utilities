using System;
using System.Collections.Generic;

using ATAP.Utilities.Philote;
namespace ATAP.Utilities.GenerateProgram {

  public class GGenerateCodeProgressReport :  IGGenerateCodeProgressReport {
    public GGenerateCodeProgressReport() {
      Philote = new Philote<IGGenerateCodeProgressReport>();
    }

    public IPhilote<IGGenerateCodeProgressReport> Philote { get; init; }

    void IProgress<string>.Report(string value) {
      throw new NotImplementedException();
    }
  }
}
