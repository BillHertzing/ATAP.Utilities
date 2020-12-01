using QuickGraph;
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
    DateTime EarliestDirectoryCreationTime { get; set; }
    DateTime LatestDirectoryCreationTime { get; set; }
    DateTime EarliestFileCreationTime { get; set; }
    DateTime LatestFileCreationTime { get; set; }
    DateTime EarliestFileModificationTime { get; set; }
    DateTime LatestFileModificationTime { get; set; }
    void UpdateWithFile(FSEntityFile vertex);
    void UpdateWithDirectory(FSEntityDirectory vertex);
  }

}
