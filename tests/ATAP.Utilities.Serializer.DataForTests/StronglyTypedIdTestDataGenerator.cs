using System;
using System.Collections;
using System.Collections.Generic;

using ATAP.Utilities.StronglyTypedIds;

namespace ATAP.Utilities.Serializer.DataForTests
{
  public class StronglyTypedIdInterfaceTestData<TValue> where TValue : notnull {
    public IAbstractStronglyTypedId<TValue> InstanceTestData { get; set; }
    public string SerializedTestData { get; set; }

    public StronglyTypedIdInterfaceTestData() {
    }

    public StronglyTypedIdInterfaceTestData(IAbstractStronglyTypedId<TValue> instanceTestData, string serializedTestData) {
      InstanceTestData = instanceTestData;
      SerializedTestData = serializedTestData ?? throw new ArgumentNullException(nameof(serializedTestData));
    }
  }

  public class StronglyTypedIdInterfaceTestDataGenerator<TValue> : IEnumerable<object[]> where TValue : notnull {
    public static IEnumerable<object[]> StronglyTypedIdTestData() {
      switch (typeof(TValue)) {
        case { } guidType when typeof(TValue) == typeof(Guid): {
            yield return new StronglyTypedIdInterfaceTestData<TValue>[] { new StronglyTypedIdInterfaceTestData<TValue> { InstanceTestData = (IAbstractStronglyTypedId<TValue>)new GuidStronglyTypedId(Guid.Empty), SerializedTestData = "\"00000000-0000-0000-0000-000000000000\"" } };
            yield return new StronglyTypedIdInterfaceTestData<TValue>[] { new StronglyTypedIdInterfaceTestData<TValue> { InstanceTestData = (IAbstractStronglyTypedId<TValue>)new GuidStronglyTypedId(new Guid("01234567-abcd-9876-cdef-456789abcdef")), SerializedTestData = "\"01234567-abcd-9876-cdef-456789abcdef\"" } };
            yield return new StronglyTypedIdInterfaceTestData<TValue>[] { new StronglyTypedIdInterfaceTestData<TValue> { InstanceTestData = (IAbstractStronglyTypedId<TValue>)new GuidStronglyTypedId(Guid.NewGuid()), SerializedTestData = "" } };
          }
          break;
        case { } intType when typeof(TValue) == typeof(int): {
            yield return new StronglyTypedIdInterfaceTestData<TValue>[] { new StronglyTypedIdInterfaceTestData<TValue> { InstanceTestData = (IAbstractStronglyTypedId<TValue>)new IntStronglyTypedId(0), SerializedTestData = "0" } };
            yield return new StronglyTypedIdInterfaceTestData<TValue>[] { new StronglyTypedIdInterfaceTestData<TValue> { InstanceTestData = (IAbstractStronglyTypedId<TValue>)new IntStronglyTypedId(1234567), SerializedTestData = "1234567" } };
            yield return new StronglyTypedIdInterfaceTestData<TValue>[] { new StronglyTypedIdInterfaceTestData<TValue> { InstanceTestData = (IAbstractStronglyTypedId<TValue>)new IntStronglyTypedId(new Random().Next()), SerializedTestData = "" } };
          }
          break;
        // ToDo: replace with new custom exception and localization of exception message
        default:
          throw new Exception(FormattableString.Invariant($"Invalid TValue type {typeof(TValue)}"));
      }
    }

    public IEnumerator<object[]> GetEnumerator() { return StronglyTypedIdTestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }

  public class GuidStronglyTypedIdTestData {
    public GuidStronglyTypedId InstanceTestData { get; set; }
    public string SerializedTestData { get; set; }

    public GuidStronglyTypedIdTestData() {
    }

    public GuidStronglyTypedIdTestData(GuidStronglyTypedId instanceTestData, string serializedTestData) {
      InstanceTestData = instanceTestData;
      SerializedTestData = serializedTestData ?? throw new ArgumentNullException(nameof(serializedTestData));
    }
  }

  public class GuidStronglyTypedIdTestDataGenerator : IEnumerable<object[]> {
    public static IEnumerable<object[]> StronglyTypedIdTestData() {
      yield return new GuidStronglyTypedIdTestData[] { new GuidStronglyTypedIdTestData { InstanceTestData = new GuidStronglyTypedId(Guid.Empty), SerializedTestData = "\"00000000-0000-0000-0000-000000000000\"" } };
      yield return new GuidStronglyTypedIdTestData[] { new GuidStronglyTypedIdTestData { InstanceTestData = new GuidStronglyTypedId(new Guid("01234567-abcd-9876-cdef-456789abcdef")), SerializedTestData = "\"01234567-abcd-9876-cdef-456789abcdef\"" } };
      yield return new GuidStronglyTypedIdTestData[] { new GuidStronglyTypedIdTestData { InstanceTestData = new GuidStronglyTypedId(new Guid("A1234567-abcd-9876-cdef-456789abcdef")), SerializedTestData = "\"A1234567-abcd-9876-cdef-456789abcdef\"" } };
      yield return new GuidStronglyTypedIdTestData[] { new GuidStronglyTypedIdTestData { InstanceTestData = new GuidStronglyTypedId(Guid.NewGuid()), SerializedTestData = "" } };
    }

    public IEnumerator<object[]> GetEnumerator() { return StronglyTypedIdTestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }

  public class IntStronglyTypedIdTestData {
    public IntStronglyTypedId InstanceTestData { get; set; }
    public string SerializedTestData { get; set; }

    public IntStronglyTypedIdTestData() {
    }

    public IntStronglyTypedIdTestData(IntStronglyTypedId instanceTestData, string serializedTestData) {
      InstanceTestData = instanceTestData;
      SerializedTestData = serializedTestData ?? throw new ArgumentNullException(nameof(serializedTestData));
    }
  }

  public class IntStronglyTypedIdTestDataGenerator : IEnumerable<object[]> {
    public static IEnumerable<object[]> StronglyTypedIdTestData() {
      yield return new IntStronglyTypedIdTestData[] { new IntStronglyTypedIdTestData { InstanceTestData = new IntStronglyTypedId(0), SerializedTestData = "0" } };
      yield return new IntStronglyTypedIdTestData[] { new IntStronglyTypedIdTestData { InstanceTestData = new IntStronglyTypedId(-1), SerializedTestData = "-1" } };
      yield return new IntStronglyTypedIdTestData[] { new IntStronglyTypedIdTestData { InstanceTestData = new IntStronglyTypedId(Int32.MinValue), SerializedTestData = "-2147483648" } };
      yield return new IntStronglyTypedIdTestData[] { new IntStronglyTypedIdTestData { InstanceTestData = new IntStronglyTypedId(Int32.MaxValue), SerializedTestData = "2147483647" } };
      yield return new IntStronglyTypedIdTestData[] { new IntStronglyTypedIdTestData { InstanceTestData = new IntStronglyTypedId(1234567), SerializedTestData = "1234567" } };
      yield return new IntStronglyTypedIdTestData[] { new IntStronglyTypedIdTestData { InstanceTestData = new IntStronglyTypedId(new Random().Next()), SerializedTestData = "" } };
    }

    public IEnumerator<object[]> GetEnumerator() { return StronglyTypedIdTestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }
}
