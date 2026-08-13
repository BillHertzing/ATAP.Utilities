using System;
using System.Collections.Generic;

namespace ATAP.Utilities.ComputerInventory.Hardware {
  public interface IConvertFileSystemToGraphResult {
    IList<Exception> AcceptableExceptions { get; }
    AggregateException? AggregateException { get; set; }
    FSEntityAdjacencyGraph FSEntityAdjacencyGraph { get; }
    bool Success { get; set; }
    int DeepestDirectoryTree { get; set; }
    long LargestFile { get; set; }
    System.DateTime EarliestDirectoryCreationTime { get; set; }
    System.DateTime LatestDirectoryCreationTime { get; set; }
    System.DateTime EarliestFileCreationTime { get; set; }
    System.DateTime LatestFileCreationTime { get; set; }
    System.DateTime EarliestFileModificationTime { get; set; }
    System.DateTime LatestFileModificationTime { get; set; }
    void UpdateWithFile(FSEntityFile vertex);
    void UpdateWithDirectory(FSEntityDirectory vertex);
  }

}
