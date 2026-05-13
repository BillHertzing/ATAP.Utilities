using System.Collections.Generic;
using System.Collections;
using ATAP.Utilities.StronglyTypedID;
using System;


namespace ATAP.Utilities.StronglyTypedID.UnitTests {

  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class StronglyTypedIDInterfaceSerializationTestData<TValue>  where TValue : notnull {
    public IStronglyTypedID<TValue> InstanceTestData { get; set; }
    public string SerializedTestData { get; set; }

    public StronglyTypedIDInterfaceSerializationTestData() {
    }

    public StronglyTypedIDInterfaceSerializationTestData(IStronglyTypedID<TValue> instanceTestData, string serializedTestData) {
      InstanceTestData = instanceTestData;
      SerializedTestData = serializedTestData ?? throw new ArgumentNullException(nameof(serializedTestData));
    }
  }

  public class StronglyTypedIDInterfaceSerializationTestDataGenerator<TValue> : IEnumerable<object[]> where TValue : notnull  {
    public static IEnumerable<object[]> StronglyTypedIDSerializationTestData() {
      switch (typeof(TValue)) {
        case Type guidType when typeof(TValue) == typeof(Guid): {
            yield return new StronglyTypedIDInterfaceSerializationTestData<TValue>[] { new StronglyTypedIDInterfaceSerializationTestData<TValue> { InstanceTestData = (IStronglyTypedID<TValue>)new GuidStronglyTypedID(Guid.Empty), SerializedTestData = "\"00000000-0000-0000-0000-000000000000\"" } };
            yield return new StronglyTypedIDInterfaceSerializationTestData<TValue>[] { new StronglyTypedIDInterfaceSerializationTestData<TValue> { InstanceTestData = (IStronglyTypedID<TValue>)new GuidStronglyTypedID(new Guid("01234567-abcd-9876-cdef-456789abcdef")), SerializedTestData = "\"01234567-abcd-9876-cdef-456789abcdef\"" } };
            yield return new StronglyTypedIDInterfaceSerializationTestData<TValue>[] { new StronglyTypedIDInterfaceSerializationTestData<TValue> { InstanceTestData = (IStronglyTypedID<TValue>)new GuidStronglyTypedID(Guid.NewGuid()), SerializedTestData = "" } };
          }
          break;
        case Type intType when typeof(TValue) == typeof(int): {
            yield return new StronglyTypedIDInterfaceSerializationTestData<TValue>[] { new StronglyTypedIDInterfaceSerializationTestData<TValue> { InstanceTestData = (IStronglyTypedID<TValue>)new IntStronglyTypedID(0), SerializedTestData = "0" } };
            yield return new StronglyTypedIDInterfaceSerializationTestData<TValue>[] { new StronglyTypedIDInterfaceSerializationTestData<TValue> { InstanceTestData = (IStronglyTypedID<TValue>)new IntStronglyTypedID(1234567), SerializedTestData = "1234567" } };
            yield return new StronglyTypedIDInterfaceSerializationTestData<TValue>[] { new StronglyTypedIDInterfaceSerializationTestData<TValue> { InstanceTestData = (IStronglyTypedID<TValue>)new IntStronglyTypedID(new Random().Next()), SerializedTestData = "" } };
          }
          break;
        // ToDo: replace with new custom exception and localization of exception message
        default:
          throw new Exception(FormattableString.Invariant($"Invalid TValue type {typeof(TValue)}"));
      }
    }

    public IEnumerator<object[]> GetEnumerator() { return StronglyTypedIDSerializationTestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }

  public class GuidStronglyTypedIDSerializationTestData {
    public GuidStronglyTypedID InstanceTestData { get; set; }
    public string SerializedTestData { get; set; }

    public GuidStronglyTypedIDSerializationTestData() {
    }

    public GuidStronglyTypedIDSerializationTestData(GuidStronglyTypedID instanceTestData, string serializedTestData) {
      InstanceTestData = instanceTestData;
      SerializedTestData = serializedTestData ?? throw new ArgumentNullException(nameof(serializedTestData));
    }
  }

  public class GuidStronglyTypedIDSerializationTestDataGenerator : IEnumerable<object[]> {
    public static IEnumerable<object[]> StronglyTypedIDSerializationTestData() {
      yield return new GuidStronglyTypedIDSerializationTestData[] { new GuidStronglyTypedIDSerializationTestData { InstanceTestData = new GuidStronglyTypedID(Guid.Empty), SerializedTestData = "\"00000000-0000-0000-0000-000000000000\"" } };
      yield return new GuidStronglyTypedIDSerializationTestData[] { new GuidStronglyTypedIDSerializationTestData { InstanceTestData = new GuidStronglyTypedID(new Guid("01234567-abcd-9876-cdef-456789abcdef")), SerializedTestData = "\"01234567-abcd-9876-cdef-456789abcdef\"" } };
      yield return new GuidStronglyTypedIDSerializationTestData[] { new GuidStronglyTypedIDSerializationTestData { InstanceTestData = new GuidStronglyTypedID(new Guid("A1234567-abcd-9876-cdef-456789abcdef")), SerializedTestData = "\"A1234567-abcd-9876-cdef-456789abcdef\"" } };
      yield return new GuidStronglyTypedIDSerializationTestData[] { new GuidStronglyTypedIDSerializationTestData { InstanceTestData = new GuidStronglyTypedID(Guid.NewGuid()), SerializedTestData = "" } };
    }

    public IEnumerator<object[]> GetEnumerator() { return StronglyTypedIDSerializationTestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }

  public class IntStronglyTypedIDSerializationTestData {
    public IntStronglyTypedID InstanceTestData { get; set; }
    public string SerializedTestData { get; set; }

    public IntStronglyTypedIDSerializationTestData() {
    }

    public IntStronglyTypedIDSerializationTestData(IntStronglyTypedID instanceTestData, string serializedTestData) {
      InstanceTestData = instanceTestData;
      SerializedTestData = serializedTestData ?? throw new ArgumentNullException(nameof(serializedTestData));
    }
  }

  public class IntStronglyTypedIDSerializationTestDataGenerator : IEnumerable<object[]> {
    public static IEnumerable<object[]> StronglyTypedIDSerializationTestData() {
      yield return new IntStronglyTypedIDSerializationTestData[] { new IntStronglyTypedIDSerializationTestData { InstanceTestData = new IntStronglyTypedID(0), SerializedTestData = "0" } };
      yield return new IntStronglyTypedIDSerializationTestData[] { new IntStronglyTypedIDSerializationTestData { InstanceTestData = new IntStronglyTypedID(-1), SerializedTestData = "-1" } };
      yield return new IntStronglyTypedIDSerializationTestData[] { new IntStronglyTypedIDSerializationTestData { InstanceTestData = new IntStronglyTypedID(Int32.MinValue), SerializedTestData = "-2147483648" } };
      yield return new IntStronglyTypedIDSerializationTestData[] { new IntStronglyTypedIDSerializationTestData { InstanceTestData = new IntStronglyTypedID(Int32.MaxValue), SerializedTestData = "2147483647" } };
      yield return new IntStronglyTypedIDSerializationTestData[] { new IntStronglyTypedIDSerializationTestData { InstanceTestData = new IntStronglyTypedID(1234567), SerializedTestData = "1234567" } };
      yield return new IntStronglyTypedIDSerializationTestData[] { new IntStronglyTypedIDSerializationTestData { InstanceTestData = new IntStronglyTypedID(new Random().Next()), SerializedTestData = "" } };
    }

    public IEnumerator<object[]> GetEnumerator() { return StronglyTypedIDSerializationTestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }
}
