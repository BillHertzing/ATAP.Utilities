using System.Collections;
using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.StronglyTypedId.Tests {
  public sealed record IntIdTestData(IntStronglyTypedId IntId, string SerializedIntId);

  public sealed class IntIdTestDataGenerator : IEnumerable<object[]> {
    public static IEnumerable<object[]> IntIdTestData() {
      yield return new object[] { new IntIdTestData(new IntStronglyTypedId(int.MinValue), int.MinValue.ToString(System.Globalization.CultureInfo.InvariantCulture)) };
      yield return new object[] { new IntIdTestData(new IntStronglyTypedId(-1), "-1") };
      yield return new object[] { new IntIdTestData(new IntStronglyTypedId(0), "0") };
      yield return new object[] { new IntIdTestData(new IntStronglyTypedId(1234567), "1234567") };
      yield return new object[] { new IntIdTestData(new IntStronglyTypedId(int.MaxValue), int.MaxValue.ToString(System.Globalization.CultureInfo.InvariantCulture)) };
    }

    public IEnumerator<object[]> GetEnumerator() => IntIdTestData().GetEnumerator();
    IEnumerator IEnumerable.GetEnumerator() => GetEnumerator();
  }
}
