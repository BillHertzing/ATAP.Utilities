using System;
using System.Collections;
using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.StronglyTypedId.Tests {
  public sealed record GuidIdTestData(IGuidStronglyTypedId GuidId, string SerializedGuidId);

  public sealed class GuidIdTestDataGenerator : IEnumerable<object[]> {
    public static IEnumerable<object[]> GuidIdTestData() {
      yield return new object[] { new GuidIdTestData(new GuidStronglyTypedId(Guid.Empty), "\"00000000-0000-0000-0000-000000000000\"") };
      yield return new object[] { new GuidIdTestData(new GuidStronglyTypedId(new Guid("01234567-abcd-9876-cdef-456789abcdef")), "\"01234567-abcd-9876-cdef-456789abcdef\"") };
      yield return new object[] { new GuidIdTestData(new GuidStronglyTypedId(new Guid("a1234567-abcd-9876-cdef-456789abcdef")), "\"a1234567-abcd-9876-cdef-456789abcdef\"") };
    }

    public IEnumerator<object[]> GetEnumerator() => GuidIdTestData().GetEnumerator();
    IEnumerator IEnumerable.GetEnumerator() => GetEnumerator();
  }
}
