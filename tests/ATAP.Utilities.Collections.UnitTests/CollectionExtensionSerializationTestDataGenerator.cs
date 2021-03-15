using System.Collections.Generic;
using System.Collections;
using ATAP.Utilities.Collection;
using System;


namespace ATAP.Utilities.Collection.UnitTests {

  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class CollectionExtensionSerializationTestData<T> {
    public IEnumerable<T> InstanceTestData { get; set; }
    public string SerializedTestData { get; set; }

    public CollectionExtensionSerializationTestData() {
    }

    public CollectionExtensionSerializationTestData(IEnumerable<T> instanceTestData, string serializedTestData) {
      InstanceTestData = instanceTestData;
      SerializedTestData = serializedTestData ?? throw new ArgumentNullException(nameof(serializedTestData));
    }
  }

  public class CollectionExtensionSerializationTestDataGenerator<T> : IEnumerable<object[]> {
    public static IEnumerable<object[]> StronglyTypedIdSerializationTestData() {
      switch (typeof(T)) {
        case Type guidType when typeof(T) == typeof(Guid): {
            yield return new CollectionExtensionSerializationTestData<T>[] { new CollectionExtensionSerializationTestData<T> { InstanceTestData = (ATAP.Utilities.Collection.IEnumerable<T>)new GuidStronglyTypedId(Guid.Empty), SerializedTestData = "\"00000000-0000-0000-0000-000000000000\"" } };
            yield return new CollectionExtensionSerializationTestData<T>[] { new CollectionExtensionSerializationTestData<T> { InstanceTestData = (ATAP.Utilities.Collection.IEnumerable<T>)new GuidStronglyTypedId(new Guid("01234567-abcd-9876-cdef-456789abcdef")), SerializedTestData = "\"01234567-abcd-9876-cdef-456789abcdef\"" } };
            yield return new CollectionExtensionSerializationTestData<T>[] { new CollectionExtensionSerializationTestData<T> { InstanceTestData = (ATAP.Utilities.Collection.IEnumerable<T>)new GuidStronglyTypedId(Guid.NewGuid()), SerializedTestData = "" } };
          }
          break;
        case Type intType when typeof(T) == typeof(int): {
            yield return new CollectionExtensionSerializationTestData<T>[] { new CollectionExtensionSerializationTestData<T> { InstanceTestData = (ATAP.Utilities.Collection.IEnumerable<T>)new IntStronglyTypedId(0), SerializedTestData = "0" } };
            yield return new CollectionExtensionSerializationTestData<T>[] { new CollectionExtensionSerializationTestData<T> { InstanceTestData = (ATAP.Utilities.Collection.IEnumerable<T>)new IntStronglyTypedId(1234567), SerializedTestData = "1234567" } };
            yield return new CollectionExtensionSerializationTestData<T>[] { new CollectionExtensionSerializationTestData<T> { InstanceTestData = (ATAP.Utilities.Collection.IEnumerable<T>)new IntStronglyTypedId(new Random().Next()), SerializedTestData = "" } };
          }
          break;
        // ToDo: replace with new custom exception and localization of exception message
        default:
          throw new Exception(FormattableString.Invariant($"Invalid T type {typeof(T)}"));
      }
    }

    public IEnumerator<object[]> GetEnumerator() { return StronglyTypedIdSerializationTestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }

}
