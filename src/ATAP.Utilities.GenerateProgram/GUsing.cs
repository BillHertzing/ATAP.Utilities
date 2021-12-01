using System;
using System.Collections.Generic;
using System.Text;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {

  public record GUsingId<TValue> : AbstractStronglyTypedId<TValue>, IGUsingId<TValue> where TValue : notnull {}
  public record GUsing<TValue> : IGUsing<TValue> where TValue : notnull {
    public GUsing(string gName) {
      GName = gName ?? throw new ArgumentNullException(nameof(gName));
      Id = new GUsingId<TValue>();
    }

    public string GName { get; init; }
    public  IGUsingId Id { get; init; }
  }
}






