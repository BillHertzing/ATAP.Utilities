using QuickGraph;
using System;
using System.Collections.Generic;

namespace ATAP.Utilities.ComputerInventory.Hardware {
  public interface IConvertFileSystemToGraphResult {
    IList<Exception> AcceptableExceptions { get; }
    AggregateException? AggregateException { get; set; }
    FSEntityAdjacencyGraph FSEntityAdjacencyGraph { get; }
    bool Success { get; set; }
  }

}
