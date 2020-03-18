using ATAP.Utilities.GraphDataStructures;
using System;
using System.Collections.Generic;

namespace ATAP.Utilities.ComputerInventory.Hardware
{
  public interface IConvertFileSystemToGraphResult
  {
    IList<Exception> AcceptableExceptions { get; }
    AggregateException AggregateException { get; set; }
    IGraphAsIList<IFSEntityAbstract> GraphAsIList { get; }
    bool Success { get; set; }
  }

}
