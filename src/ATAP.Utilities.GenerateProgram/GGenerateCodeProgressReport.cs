using System;
using System.Collections.Generic;

using ATAP.Utilities.StronglyTypedId;
namespace ATAP.Utilities.GenerateProgram {

  public record GGenerateCodeProgressId<TValue> : AbstractStronglyTypedId<TValue>, IGGenerateCodeProgressId<TValue> where TValue : notnull {}
  public class GGenerateCodeProgress<TValue> : IGGenerateCodeProgress<TValue> where TValue : notnull {
    public GGenerateCodeProgress() {
      Id = new GGenerateCodeProgressId<TValue>();
    }

    public  IGGenerateCodeProgressId Id { get; init; }

    void IProgress<string>.Report(string value) {
      throw new NotImplementedException();
    }
  }
}






