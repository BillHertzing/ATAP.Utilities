using System;
using System.Collections.Generic;

namespace ATAP.Utilities.GraphDataStructures
{
  public interface IEdge<T>
  {
    IVertex<T> From { get; }
    IVertex<T> To { get; }
  }
}
