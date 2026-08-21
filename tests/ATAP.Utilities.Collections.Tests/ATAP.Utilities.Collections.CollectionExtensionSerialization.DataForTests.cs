using System;
using System.Collections;
using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.Collection.Tests {
  public sealed record GuidStronglyTypedIdSerializationTestData(GuidStronglyTypedId InstanceTestData, string SerializedTestData);

  public sealed class GuidStronglyTypedIdSerializationTestDataGenerator : IEnumerable<object[]> {
    public static IEnumerable<object[]> Data() {
      yield return new object[] { new GuidStronglyTypedIdSerializationTestData(new GuidStronglyTypedId(Guid.Empty), "\"00000000-0000-0000-0000-000000000000\"") };
      yield return new object[] { new GuidStronglyTypedIdSerializationTestData(new GuidStronglyTypedId(new Guid("01234567-abcd-9876-cdef-456789abcdef")), "\"01234567-abcd-9876-cdef-456789abcdef\"") };
      yield return new object[] { new GuidStronglyTypedIdSerializationTestData(new GuidStronglyTypedId(new Guid("a1234567-abcd-9876-cdef-456789abcdef")), "\"a1234567-abcd-9876-cdef-456789abcdef\"") };
    }

    public IEnumerator<object[]> GetEnumerator() => Data().GetEnumerator();
    IEnumerator IEnumerable.GetEnumerator() => GetEnumerator();
  }

  public sealed record IntStronglyTypedIdSerializationTestData(IntStronglyTypedId InstanceTestData, string SerializedTestData);

  public sealed class IntStronglyTypedIdSerializationTestDataGenerator : IEnumerable<object[]> {
    public static IEnumerable<object[]> Data() {
      yield return new object[] { new IntStronglyTypedIdSerializationTestData(new IntStronglyTypedId(int.MinValue), int.MinValue.ToString(System.Globalization.CultureInfo.InvariantCulture)) };
      yield return new object[] { new IntStronglyTypedIdSerializationTestData(new IntStronglyTypedId(-1), "-1") };
      yield return new object[] { new IntStronglyTypedIdSerializationTestData(new IntStronglyTypedId(0), "0") };
      yield return new object[] { new IntStronglyTypedIdSerializationTestData(new IntStronglyTypedId(1234567), "1234567") };
      yield return new object[] { new IntStronglyTypedIdSerializationTestData(new IntStronglyTypedId(int.MaxValue), int.MaxValue.ToString(System.Globalization.CultureInfo.InvariantCulture)) };
    }

    public IEnumerator<object[]> GetEnumerator() => Data().GetEnumerator();
    IEnumerator IEnumerable.GetEnumerator() => GetEnumerator();
  }

  public sealed record CollectionExtensionSerializationTestData<T>(IReadOnlyList<T> InstanceTestData, string SerializedTestData);

  public static class CollectionExtensionSerializationTestDataGenerator {
    public static IEnumerable<object[]> GuidData() {
      yield return new object[] {
        new CollectionExtensionSerializationTestData<GuidStronglyTypedId>(
          new[] { new GuidStronglyTypedId(Guid.Empty), new GuidStronglyTypedId(new Guid("01234567-abcd-9876-cdef-456789abcdef")) },
          "[\"00000000-0000-0000-0000-000000000000\",\"01234567-abcd-9876-cdef-456789abcdef\"]")
      };
      yield return new object[] {
        new CollectionExtensionSerializationTestData<GuidStronglyTypedId>(Array.Empty<GuidStronglyTypedId>(), "[]")
      };
    }

    public static IEnumerable<object[]> IntData() {
      yield return new object[] {
        new CollectionExtensionSerializationTestData<IntStronglyTypedId>(
          new[] { new IntStronglyTypedId(int.MinValue), new IntStronglyTypedId(0), new IntStronglyTypedId(int.MaxValue) },
          "[-2147483648,0,2147483647]")
      };
      yield return new object[] {
        new CollectionExtensionSerializationTestData<IntStronglyTypedId>(Array.Empty<IntStronglyTypedId>(), "[]")
      };
    }
  }
}
