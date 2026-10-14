using System;
using System.Net.Http;
using System.Threading.Tasks;
using ATAP.Utilities.Http;
using Xunit;
using Xunit.Abstractions;

namespace ATAP.Utilities.Http.Tests
{
  
        [Trait("Category", "Unit")]
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
            protected Fixture fixture;
            readonly ITestOutputHelper output;

            public HttpUnitTests(ITestOutputHelper output, Fixture fixture)
            {
                this.output = output;
                this.fixture = fixture;
            }

            [Fact]
            public void GetJsonFromUrl_PublicContract_UsesModernOptionalCallbacksAndStringReturn()
            {
                // Arrange
                var method = typeof(Gateway).GetMethod(nameof(Gateway.GetJsonFromUrl));

                // Act
                var parameters = method?.GetParameters();

                // Assert
                Assert.NotNull(method);
                Assert.Equal(typeof(string), method.ReturnType);
                Assert.NotNull(parameters);
                Assert.Collection(parameters,
                    entry => Assert.Equal(typeof(IGatewayEntry), entry.ParameterType),
                    requestFilter => AssertOptionalNullDelegate<Action<HttpRequestMessage>>(requestFilter),
                    responseFilter => AssertOptionalNullDelegate<Action<HttpResponseMessage>>(responseFilter));
            }

            [Fact]
            public void PostJsonToUrlAsync_PublicContract_UsesModernOptionalCallbacksAndTaskStringReturn()
            {
                // Arrange
                var method = typeof(Gateway).GetMethod(nameof(Gateway.PostJsonToUrlAsync));

                // Act
                var parameters = method?.GetParameters();

                // Assert
                Assert.NotNull(method);
                Assert.Equal(typeof(Task<string>), method.ReturnType);
                Assert.NotNull(parameters);
                Assert.Collection(parameters,
                    entry => Assert.Equal(typeof(IGatewayEntry), entry.ParameterType),
                    json => Assert.Equal(typeof(string), json.ParameterType),
                    requestFilter => AssertOptionalNullDelegate<Action<HttpRequestMessage>>(requestFilter),
                    responseFilter => AssertOptionalNullDelegate<Action<HttpResponseMessage>>(responseFilter));
            }

            private static void AssertOptionalNullDelegate<TDelegate>(System.Reflection.ParameterInfo parameter)
            {
                Assert.Equal(typeof(TDelegate), parameter.ParameterType);
                Assert.True(parameter.IsOptional);
                Assert.True(parameter.HasDefaultValue);
                Assert.Null(parameter.DefaultValue);
            }
        }
}
