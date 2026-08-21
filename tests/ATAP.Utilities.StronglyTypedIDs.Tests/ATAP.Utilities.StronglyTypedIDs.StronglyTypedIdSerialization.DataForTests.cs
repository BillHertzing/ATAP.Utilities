using System;
using System.Collections;
using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.StronglyTypedId.Tests {
  public sealed record StronglyTypedIdInterfaceSerializationTestData<TValue>(
    IAbstractStronglyTypedId<TValue> InstanceTestData,
    string SerializedTestData) where TValue : notnull;

  public sealed class StronglyTypedIdInterfaceSerializationTestDataGenerator<TValue> : IEnumerable<object[]> where TValue : notnull {
    public static IEnumerable<object[]> StronglyTypedIdSerializationTestData() {
      if (typeof(TValue) == typeof(Guid)) {
        yield return new object[] { new StronglyTypedIdInterfaceSerializationTestData<TValue>((IAbstractStronglyTypedId<TValue>)(object)new GuidStronglyTypedId(Guid.Empty), "\"00000000-0000-0000-0000-000000000000\"") };
        yield return new object[] { new StronglyTypedIdInterfaceSerializationTestData<TValue>((IAbstractStronglyTypedId<TValue>)(object)new GuidStronglyTypedId(new Guid("01234567-abcd-9876-cdef-456789abcdef")), "\"01234567-abcd-9876-cdef-456789abcdef\"") };
        yield return new object[] { new StronglyTypedIdInterfaceSerializationTestData<TValue>((IAbstractStronglyTypedId<TValue>)(object)new GuidStronglyTypedId(new Guid("a1234567-abcd-9876-cdef-456789abcdef")), "\"a1234567-abcd-9876-cdef-456789abcdef\"") };
        yield break;
      }

      if (typeof(TValue) == typeof(int)) {
        yield return new object[] { new StronglyTypedIdInterfaceSerializationTestData<TValue>((IAbstractStronglyTypedId<TValue>)(object)new IntStronglyTypedId(int.MinValue), int.MinValue.ToString(System.Globalization.CultureInfo.InvariantCulture)) };
        yield return new object[] { new StronglyTypedIdInterfaceSerializationTestData<TValue>((IAbstractStronglyTypedId<TValue>)(object)new IntStronglyTypedId(-1), "-1") };
        yield return new object[] { new StronglyTypedIdInterfaceSerializationTestData<TValue>((IAbstractStronglyTypedId<TValue>)(object)new IntStronglyTypedId(0), "0") };
        yield return new object[] { new StronglyTypedIdInterfaceSerializationTestData<TValue>((IAbstractStronglyTypedId<TValue>)(object)new IntStronglyTypedId(1234567), "1234567") };
        yield return new object[] { new StronglyTypedIdInterfaceSerializationTestData<TValue>((IAbstractStronglyTypedId<TValue>)(object)new IntStronglyTypedId(int.MaxValue), int.MaxValue.ToString(System.Globalization.CultureInfo.InvariantCulture)) };
        yield break;
      }

      throw new NotSupportedException($"Unsupported strongly typed ID value type {typeof(TValue)}.");
    }

    public IEnumerator<object[]> GetEnumerator() => StronglyTypedIdSerializationTestData().GetEnumerator();
    IEnumerator IEnumerable.GetEnumerator() => GetEnumerator();
  }

  public sealed record GuidStronglyTypedIdSerializationTestData(GuidStronglyTypedId InstanceTestData, string SerializedTestData);

  public sealed class GuidStronglyTypedIdSerializationTestDataGenerator : IEnumerable<object[]> {
    public static IEnumerable<object[]> StronglyTypedIdSerializationTestData() {
      foreach (var row in GuidIdTestDataGenerator.GuidIdTestData()) {
        var source = (GuidIdTestData)row[0];
        yield return new object[] { new GuidStronglyTypedIdSerializationTestData((GuidStronglyTypedId)source.GuidId, source.SerializedGuidId) };
      }
    }

    public IEnumerator<object[]> GetEnumerator() => StronglyTypedIdSerializationTestData().GetEnumerator();
    IEnumerator IEnumerable.GetEnumerator() => GetEnumerator();
  }

  public sealed record IntStronglyTypedIdSerializationTestData(IntStronglyTypedId InstanceTestData, string SerializedTestData);

  public sealed class IntStronglyTypedIdSerializationTestDataGenerator : IEnumerable<object[]> {
    public static IEnumerable<object[]> StronglyTypedIdSerializationTestData() {
      foreach (var row in IntIdTestDataGenerator.IntIdTestData()) {
        var source = (IntIdTestData)row[0];
        yield return new object[] { new IntStronglyTypedIdSerializationTestData(source.IntId, source.SerializedIntId) };
      }
    }

    public IEnumerator<object[]> GetEnumerator() => StronglyTypedIdSerializationTestData().GetEnumerator();
    IEnumerator IEnumerable.GetEnumerator() => GetEnumerator();
  }
}
