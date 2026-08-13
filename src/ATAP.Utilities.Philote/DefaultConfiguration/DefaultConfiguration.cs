using System;
using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.Philote;

public static class GuidPhiloteDefaultConfiguration<TId>
  where TId : GuidStronglyTypedId, new()
{
  public static IReadOnlyDictionary<string, IGuidPhilote<TId>> Production { get; } =
    new Dictionary<string, IGuidPhilote<TId>>(StringComparer.Ordinal)
    {
      ["Generic"] = new GuidPhilote<TId>(),
      ["Contrived"] = new GuidPhilote<TId>(CreateId(new Guid("01234567-abcd-9876-cdef-456789abcdef")))
    };

  private static TId CreateId(Guid value) =>
    (TId)(Activator.CreateInstance(typeof(TId), value)
      ?? throw new InvalidOperationException($"Could not create '{typeof(TId)}'."));
}

public static class IntPhiloteDefaultConfiguration<TId>
  where TId : IntStronglyTypedId, new()
{
  public static IReadOnlyDictionary<string, IIntPhilote<TId>> Production { get; } =
    new Dictionary<string, IIntPhilote<TId>>(StringComparer.Ordinal)
    {
      ["Generic"] = new IntPhilote<TId>(),
      ["Contrived"] = new IntPhilote<TId>(CreateId(1234567))
    };

  private static TId CreateId(int value) =>
    (TId)(Activator.CreateInstance(typeof(TId), value)
      ?? throw new InvalidOperationException($"Could not create '{typeof(TId)}'."));
}
