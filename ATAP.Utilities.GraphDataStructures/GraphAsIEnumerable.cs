
using System;
using System.Collections.Generic;

namespace ATAP.Utilities.GraphDataStructures
{
  public class GraphAsIEnumerable<T> : IGraphAsIEnumerable<T>
  {
    public GraphAsIEnumerable()
    {
    }

    public GraphAsIEnumerable(IEnumerable<IVertex<T>> vertices, IEnumerable<IEdge<T>> edges)
    {
      Vertices = vertices ?? throw new ArgumentNullException(nameof(vertices));
      Edges = edges ?? throw new ArgumentNullException(nameof(edges));
    }

    public IEnumerable<IVertex<T>> Vertices { get; private set; }
    public IEnumerable<IEdge<T>> Edges { get; private set; }
  }

}
