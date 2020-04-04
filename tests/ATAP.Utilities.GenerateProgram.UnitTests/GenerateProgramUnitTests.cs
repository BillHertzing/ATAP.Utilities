


using ATAP.Utilities.Testing;
using FluentAssertions;
using Xunit;
using Xunit.Abstractions;
using ATAP.Utilities.Philote;
using ATAP.Utilities.Testing.XunitSkipAttributeExtension;
using System.Collections.Generic;
using System;
using System.Diagnostics.CodeAnalysis;

namespace ATAP.Utilities.GenerateProgram.UnitTests
{


  public partial class SerializationUnitTests001 : IClassFixture<SerializationFixture>
  {

    //[Theory]
    //[MemberData(nameof(GenerateProgramTestDataGenerator.TestData), MemberType = typeof(GenerateProgramTestDataGenerator))]
    //public void GenerateProgramDeserializeFromJSON(GenerateProgramTestData inTestData)
    //{
    //  var obj = Fixture.Serializer.Deserialize<GenerateProgram>(inTestData.SerializedTestData);
    //  // ToDo Figure out how to assert that a type implements IEnuerable<T>
    //  //obj.Should().BeOfType(typeof(GenerateProgram));
    //  Fixture.Serializer.Deserialize<GenerateProgram>(inTestData.SerializedTestData).Should().BeEquivalentTo(inTestData.ObjTestData);
    //}

    //[Theory]
    //[MemberData(nameof(GenerateProgramTestDataGenerator.TestData), MemberType = typeof(GenerateProgramTestDataGenerator))]
    //public void GenerateProgramSerializeToJSON(GenerateProgramTestData inTestData)
    //{
    //  Fixture.Serializer.Serialize(inTestData.ObjTestData).Should().MatchRegex(inTestData.SerializedTestData);
    //}
  }
}
