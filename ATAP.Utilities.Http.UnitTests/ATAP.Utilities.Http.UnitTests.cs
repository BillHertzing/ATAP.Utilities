using System;
using Xunit;
using Xunit.Abstractions;

namespace ATAP.Utilities.Http.UnitTests
{
  
        public class Fixture
        {
            private string hello;

            public Fixture()
            {
                Hello = "Hello";
            }

            public string Hello { get => hello; set => hello = value; }
        }
        public class HttpUnitTests : IClassFixture<Fixture>
        {
            protected Fixture _fixture;
            readonly ITestOutputHelper output;

            public HttpUnitTests(ITestOutputHelper output, Fixture fixture)
            {
                this.output = output;
                this._fixture = fixture;
            }
        }
}
