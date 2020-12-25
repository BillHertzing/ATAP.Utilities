using System;
using System.Collections.Generic;

using ATAP.Utilities.Philote;
namespace ATAP.Utilities.GenerateProgram {

  public class GGenerateCodeProgress :  IGGenerateCodeProgress {
    public GGenerateCodeProgress() {
      Philote = new Philote<IGGenerateCodeProgress>();
    }

    public IPhilote<IGGenerateCodeProgress> Philote { get; init; }

    void IProgress<string>.Report(string value) {
      throw new NotImplementedException();
    }
  }
}
