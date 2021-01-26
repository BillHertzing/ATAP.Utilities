using System;
using System.IO;
using System.Collections.Generic;

namespace ATAP.Utilities.Persistence {
  public interface ISetupViaFileResults : ISetupResultsAbstract, IDisposable {
    (FileStream fileStream, StreamWriter streamWriter)[] FileStreamStreamWriterPairs { get; set; }

    Dictionary<string, (FileStream fileStream, StreamWriter streamWriter)> DictionaryFileStreamStreamWriterPairs { get; init; }
    new void Dispose();
  }
}
