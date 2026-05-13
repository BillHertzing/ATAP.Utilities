
using System;
using System.Collections;
using System.Collections.Generic;
using System.ComponentModel;
using ATAP.Utilities.StronglyTypedID;
using FluentAssertions;
using Xunit;
using Xunit.Abstractions;


// For the tests that use the new Serializer/Deserializer
using System.Text.Json;
// For the tests that use the old Newtonsoft Serializer/Deserializer
//using Newtonsoft.Json;

using ATAP.Utilities.Testing;
using ATAP.Utilities.Serializer;
using ATAP.Utilities.Serializer.DataForTests;

namespace ATAP.Utilities.StronglyTypedID.UnitTests {
  // Attribution: https://github.com/xunit/xunit/issues/2007, however, we only need a class fixture not a collectionfixtire, so, commentedout below
  //  [CollectionDefinition(nameof(StronglyTypedIDSerializationSystemTextJsonUnitTests001), DisableParallelization = true)]
  //  [Collection(nameof(StronglyTypedIDSerializationSystemTextJsonUnitTests001))]
  public partial class StronglyTypedIDSerializationUnitTests001 : IClassFixture<Fixture> {

    [Theory]
    [MemberData(nameof(GuidStronglyTypedIDSerializationTestDataGenerator.StronglyTypedIDSerializationTestData), MemberType = typeof(GuidStronglyTypedIDSerializationTestDataGenerator))]
    public void GuidIdSerializeToJSON(GuidStronglyTypedIDSerializationTestData inTestData) {
      // ToDo low priority localize the unit test's exception's message
      if (inTestData == null) { throw new ArgumentNullException($"{nameof(inTestData)} argument should never be null"); }
      // GUIDS are random, two sets of test data have fixed, non-random guids, the rest are random
      if (inTestData.SerializedTestData.StartsWith("\"0000", System.StringComparison.InvariantCulture) || inTestData.SerializedTestData.StartsWith("\"01234", System.StringComparison.InvariantCulture)) {
        Fixture.Serializer.Serialize(inTestData.InstanceTestData).Should().Be(inTestData.SerializedTestData);
        // JsonSerializer.Serialize(inTestData.InstanceTestData, Fixture.JsonSerializerOptions).Should().Be(inTestData.SerializedTestData);
      }
      else {
        Fixture.Serializer.Serialize(inTestData.InstanceTestData).Should().MatchRegex("^[0-9A-Fa-f]{8}-?([0-9A-Fa-f]{4}-?){3}[0-9A-Fa-f]{12}$");
        // JsonSerializer.Serialize(inTestData.InstanceTestData, Fixture.JsonSerializerOptions).Should().MatchRegex("^\"[0-9A-Fa-f]{8}-?([0-9A-Fa-f]{4}-?){3}[0-9A-Fa-f]{12}\"$");
      }
    }

    [Theory]
    [MemberData(nameof(GuidStronglyTypedIDSerializationTestDataGenerator.StronglyTypedIDSerializationTestData), MemberType = typeof(GuidStronglyTypedIDSerializationTestDataGenerator))]
    public void GuidIdDeserializeFromJSON(GuidStronglyTypedIDSerializationTestData inTestData) {
      // ToDo low priority localize the unit test's exception's message
      if (inTestData == null) { throw new ArgumentNullException($"{nameof(inTestData)} argument should never be null"); }
      if (String.IsNullOrEmpty(inTestData.SerializedTestData)) {
        Action act = () => JsonSerializer.Deserialize<GuidStronglyTypedID>(inTestData.SerializedTestData);
        act.Should().Throw<System.Text.Json.JsonException>()
          .WithMessage("The input does not contain any JSON tokens.*");
      }
      else if (inTestData.SerializedTestData.StartsWith("\"0000", System.StringComparison.InvariantCulture) || inTestData.SerializedTestData.StartsWith("\"01234", System.StringComparison.InvariantCulture)) {
        Fixture.Serializer.Deserialize<GuidStronglyTypedID>(inTestData.SerializedTestData).Should().BeEquivalentTo(inTestData.InstanceTestData);
        // var stronglyTypedID = JsonSerializer.Deserialize<GuidStronglyTypedID>(inTestData.SerializedTestData, Fixture.JsonSerializerOptions);
        // stronglyTypedID.Should().BeEquivalentTo(inTestData.InstanceTestData);
      }
      else {
        // ToDo: validate that strings that don't match a Guid throw an exception
      }
    }

    [Theory]
    [MemberData(nameof(StronglyTypedIDInterfaceSerializationTestDataGenerator<Guid>.StronglyTypedIDSerializationTestData), MemberType = typeof(StronglyTypedIDInterfaceSerializationTestDataGenerator<Guid>))]
    public void GuidStronglyTypedIDInterfaceSerializeToJSON(StronglyTypedIDInterfaceSerializationTestData<Guid> inTestData) {
      // ToDo low priority localize the unit test's exception's message
      if (inTestData == null) { throw new ArgumentNullException($"{nameof(inTestData)} argument should never be null"); }
      // GUIDS are random, two sets of test data have fixed, non-random guids, the rest are random
      if (inTestData.SerializedTestData.StartsWith("\"0000", System.StringComparison.InvariantCulture) || inTestData.SerializedTestData.StartsWith("\"01234", System.StringComparison.InvariantCulture)) {
        Fixture.Serializer.Serialize(inTestData.InstanceTestData).Should().Be(inTestData.SerializedTestData);
        // JsonSerializer.Serialize(inTestData.InstanceTestData, Fixture.JsonSerializerOptions).Should().Be(inTestData.SerializedTestData);
      }
      else {
        Fixture.Serializer.Serialize(inTestData.InstanceTestData).Should().MatchRegex("^[0-9A-Fa-f]{8}-?([0-9A-Fa-f]{4}-?){3}[0-9A-Fa-f]{12}$");
        // JsonSerializer.Serialize(inTestData.InstanceTestData, Fixture.JsonSerializerOptions).Should().MatchRegex("^\"[0-9A-Fa-f]{8}-?([0-9A-Fa-f]{4}-?){3}[0-9A-Fa-f]{12}\"$");
      }
    }

    [Theory]
    [MemberData(nameof(StronglyTypedIDInterfaceSerializationTestDataGenerator<Guid>.StronglyTypedIDSerializationTestData), MemberType = typeof(StronglyTypedIDInterfaceSerializationTestDataGenerator<Guid>))]
    public void GuidStronglyTypedIDInterfaceDeserializeFromJSON(StronglyTypedIDInterfaceSerializationTestData<Guid> inTestData) {
      // ToDo low priority localize the unit test's exception's message
      if (inTestData == null) { throw new ArgumentNullException($"{nameof(inTestData)} argument should never be null"); }
      if (String.IsNullOrEmpty(inTestData.SerializedTestData)) {
        Action act = () => JsonSerializer.Deserialize<GuidStronglyTypedID>(inTestData.SerializedTestData);
        act.Should().Throw<System.Text.Json.JsonException>()
          .WithMessage("The input does not contain any JSON tokens.*");
      }
      else if (inTestData.SerializedTestData.StartsWith("\"0000", System.StringComparison.InvariantCulture) || inTestData.SerializedTestData.StartsWith("\"01234", System.StringComparison.InvariantCulture)) {
        Fixture.Serializer.Deserialize<GuidStronglyTypedID>(inTestData.SerializedTestData).Should().BeEquivalentTo(inTestData.InstanceTestData);
        // var stronglyTypedID = JsonSerializer.Deserialize<GuidStronglyTypedID>(inTestData.SerializedTestData, Fixture.JsonSerializerOptions);
        // stronglyTypedID.Should().BeEquivalentTo(inTestData.InstanceTestData);
      }
      else {
        // ToDo: validate that strings that don't match a Guid throw an exception
      }
    }

    [Theory]
    [MemberData(nameof(IntStronglyTypedIDSerializationTestDataGenerator.StronglyTypedIDSerializationTestData), MemberType = typeof(IntStronglyTypedIDSerializationTestDataGenerator))]
    public void IntIdSerializeToJSON(IntStronglyTypedIDSerializationTestData inTestData) {
      // ToDo low priority localize the unit test's exception's message
      if (inTestData == null) { throw new ArgumentNullException($"{nameof(inTestData)} argument should never be null"); }
      // new AbstractStronglyTypedID<int>() have random Values, two sets of test data have fixed, non-random integers, the rest are random
      if (inTestData.SerializedTestData.Equals("-2147483648") || inTestData.SerializedTestData.Equals("-1") || inTestData.SerializedTestData.Equals("0") || inTestData.SerializedTestData.Equals("2147483647") || inTestData.SerializedTestData.Equals("1234567")) {
        Fixture.Serializer.Serialize(inTestData.InstanceTestData).Should().Be(inTestData.SerializedTestData);
        // JsonSerializer.Serialize(inTestData.InstanceTestData, Fixture.JsonSerializerOptions).Should().Be(inTestData.SerializedTestData);
      }
      else {
        Fixture.Serializer.Serialize(inTestData.InstanceTestData).Should().MatchRegex("^[0-9A-Fa-f]{8}-?([0-9A-Fa-f]{4}-?){3}[0-9A-Fa-f]{12}$");
        // JsonSerializer.Serialize(inTestData.InstanceTestData, Fixture.JsonSerializerOptions).Should().BeOfType(typeof(string), "the serializer should have returned a string representation of the InstanceTestData ");
        // JsonSerializer.Serialize(inTestData.InstanceTestData, Fixture.JsonSerializerOptions).Should().MatchRegex("^-{0,1}\\d+$");
      }
    }

    [Theory]
    [MemberData(nameof(IntStronglyTypedIDSerializationTestDataGenerator.StronglyTypedIDSerializationTestData), MemberType = typeof(IntStronglyTypedIDSerializationTestDataGenerator))]
    public void IntIdDeserializeFromJSON(IntStronglyTypedIDSerializationTestData inTestData) {
      // ToDo low priority localize the unit test's exception's message
      if (inTestData == null) { throw new ArgumentNullException($"{nameof(inTestData)} argument should never be null"); }
      if (String.IsNullOrEmpty(inTestData.SerializedTestData)) {
        Action act = () => JsonSerializer.Deserialize<IntStronglyTypedID>(inTestData.SerializedTestData);
        act.Should().Throw<System.Text.Json.JsonException>()
          .WithMessage("The input does not contain any JSON tokens.*");
      }
      else {
        // ToDo: validate that non-integer strings throw an exception
        Fixture.Serializer.Deserialize<IntStronglyTypedID>(inTestData.SerializedTestData).Should().BeEquivalentTo(inTestData.InstanceTestData);
        // var stronglyTypedID = JsonSerializer.Deserialize<IntStronglyTypedID>(inTestData.SerializedTestData, Fixture.JsonSerializerOptions);
        // stronglyTypedID.Should().BeEquivalentTo(inTestData.InstanceTestData);
      }
    }

    [Theory]
    [MemberData(nameof(StronglyTypedIDInterfaceSerializationTestDataGenerator<int>.StronglyTypedIDSerializationTestData), MemberType = typeof(StronglyTypedIDInterfaceSerializationTestDataGenerator<int>))]
    public void IntStronglyTypedIDInterfaceSerializeToJSON(StronglyTypedIDInterfaceSerializationTestData<int> inTestData) {
      // ToDo low priority localize the unit test's exception's message
      if (inTestData == null) { throw new ArgumentNullException($"{nameof(inTestData)} argument should never be null"); }
      if (inTestData.SerializedTestData.Equals("-2147483648") || inTestData.SerializedTestData.Equals("-1") || inTestData.SerializedTestData.Equals("0") || inTestData.SerializedTestData.Equals("2147483647") || inTestData.SerializedTestData.Equals("1234567")) {
        Fixture.Serializer.Serialize(inTestData.InstanceTestData).Should().Be(inTestData.SerializedTestData);
        //JsonSerializer.Serialize(inTestData.InstanceTestData, Fixture.JsonSerializerOptions).Should().Be(inTestData.SerializedTestData);
      }
      else {
        Fixture.Serializer.Serialize(inTestData.InstanceTestData).Should().MatchRegex("^[0-9A-Fa-f]{8}-?([0-9A-Fa-f]{4}-?){3}[0-9A-Fa-f]{12}$");
        //JsonSerializer.Serialize(inTestData.InstanceTestData, Fixture.JsonSerializerOptions).Should().BeOfType(typeof(string), "the serializer should have returned a string representation of the InstanceTestData ");
        //JsonSerializer.Serialize(inTestData.InstanceTestData, Fixture.JsonSerializerOptions).Should().MatchRegex("^-{0,1}\\d+$");
      }
    }

    [Theory]
    [MemberData(nameof(StronglyTypedIDInterfaceSerializationTestDataGenerator<int>.StronglyTypedIDSerializationTestData), MemberType = typeof(StronglyTypedIDInterfaceSerializationTestDataGenerator<int>))]
    public void IntStronglyTypedIDInterfaceDeserializeFromJSON(StronglyTypedIDInterfaceSerializationTestData<int> inTestData) {
      // ToDo low priority localize the unit test's exception's message
      if (inTestData == null) { throw new ArgumentNullException($"{nameof(inTestData)} argument should never be null"); }
      if (String.IsNullOrEmpty(inTestData.SerializedTestData)) {
        Action act = () => Fixture.Serializer.Deserialize<IntStronglyTypedID>(inTestData.SerializedTestData);
        // Action act = () => JsonSerializer.Deserialize<IntStronglyTypedID>(inTestData.SerializedTestData, Fixture.JsonSerializerOptions);
        act.Should().Throw<System.Text.Json.JsonException>()
          .WithMessage("The input does not contain any JSON tokens.*");
      }
      else {
        Fixture.Serializer.Deserialize<IntStronglyTypedID>(inTestData.SerializedTestData).Should().BeEquivalentTo(inTestData.InstanceTestData);
        //var stronglyTypedID = JsonSerializer.Deserialize<IntStronglyTypedID>(inTestData.SerializedTestData, Fixture.JsonSerializerOptions);
        //stronglyTypedID.Should().Equals(inTestData.InstanceTestData);
        // ToDo: validate that strings that don't match an int throw an exception
      }
    }
  }
}
