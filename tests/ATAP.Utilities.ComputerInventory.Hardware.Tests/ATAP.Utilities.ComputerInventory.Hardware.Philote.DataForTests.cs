using System;
using System.Collections.Generic;
using ATAP.Utilities.Philote;
using ATAP.Utilities.StronglyTypedId;
using ATAP.Utilities.Testing;

namespace ATAP.Utilities.ComputerInventory.Hardware.Tests
{
  public sealed class PhiloteTestData<T> : SerializedTestData<IGuidPhilote<GuidStronglyTypedId>>
  {
    public PhiloteTestData(IGuidPhilote<GuidStronglyTypedId> philote, string serializedPhilote)
      : base(philote, serializedPhilote)
    {
    }
  }

  public static class PhiloteTestDataGenerator<T>
  {
    public static IEnumerable<object[]> TestData()
    {
      var philote = new GuidPhilote<GuidStronglyTypedId>(new GuidStronglyTypedId(Guid.Empty));
      const string serializedPhilote =
        "{\"id\":\"00000000-0000-0000-0000-000000000000\",\"additionalIds\":{},\"validityPeriods\":[]}";

      yield return new PhiloteTestData<T>[]
      {
        new(philote, serializedPhilote)
      };
    }
  }
}
