
using System;
using System.Collections.Generic;

namespace ATAP.Utilities.GraphDataStructures
{
  public class GraphAsIList<T> : IGraphAsIList<T>
  {
    public GraphAsIList()
    {
      IList<IVertex<T>> newVertices = new List<IVertex<T>>();
      Vertices = newVertices;
      IList<IEdge<T>> newEdges = new List<IEdge<T>>();
      Edges = newEdges;
    }

    public GraphAsIList(IList<IVertex<T>> vertices, IList<IEdge<T>> edges)
    {
      Vertices = vertices ?? throw new ArgumentNullException(nameof(vertices));
      Edges = edges ?? throw new ArgumentNullException(nameof(edges));
    }

    public IList<IVertex<T>> Vertices { get; private set; }
    public IList<IEdge<T>> Edges { get; private set; }
  }

}
