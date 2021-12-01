using System;
using ATAP.Utilities.StronglyTypedId;
namespace ATAP.Utilities.GenerateProgram {
  public interface IGGenerateCodeProgressId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull {}
  public interface IGGenerateCodeProgress<TValue> : IProgress<string>, IGGenerateCodeProgressId<TValue> where TValue : notnull {

    IGGenerateCodeProgressId<TValue> Id { get; init; }
  }
}


