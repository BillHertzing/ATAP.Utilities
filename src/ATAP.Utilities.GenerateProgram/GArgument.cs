using System;
using System.Collections.Generic;
using System.Dynamic;
using System.Text;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {
  public record GArgumentId<TValue> : AbstractStronglyTypedId<TValue>, IGArgumentId<TValue> where TValue : notnull {}
  public record GArgument<TValue> : IGArgument<TValue> where TValue : notnull {
    public GArgument(string gName, string gType, bool isRef = false, bool isOut = false) {
      GName = gName ?? throw new ArgumentNullException(nameof(gName));
      GType = gType ?? throw new ArgumentNullException(nameof(gType));
      IsRef = isRef;
      IsOut = isOut;
      Id = new GArgumentId<TValue>();

    }

    public string GName { get; init;}
    public string GType { get; init; }
    public bool IsRef { get; init; }
    public bool IsOut { get; init; }
    public  IGArgumentId Id { get; init; }


  }}







