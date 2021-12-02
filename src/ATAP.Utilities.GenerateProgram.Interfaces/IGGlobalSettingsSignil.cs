using System.Collections.Generic;

using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {
  public interface IGGlobalSettingsSignilId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull {}
  public interface IGGlobalSettingsSignil<TValue> where TValue : notnull {
    ICollection<string> DefaultTargetFrameworks { get; }
  }
}


