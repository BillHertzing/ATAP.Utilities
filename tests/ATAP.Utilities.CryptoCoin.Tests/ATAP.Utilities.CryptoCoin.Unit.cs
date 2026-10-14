using System;
using System.Net;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;
using FluentAssertions;
using Xunit;

namespace ATAP.Utilities.CryptoCoin.Tests;

[Trait("Category", "Unit")]
public sealed class CryptoCoinUnitTests001
{
  [Fact]
  public async Task ChainInfo_AsyncFetch_UsesEscapedGetRequestAndDeserializesPayload()
  {
    var handler = new DelegateHandler((request, _) =>
    {
      request.Method.Should().Be(HttpMethod.Get);
      request.RequestUri!.AbsoluteUri.Should().Be("https://chain.so/api/v2/get_info/BTC%2FTEST");
      return Task.FromResult(CreateJsonResponse("{\"data\":{\"acronym\":\"BTC\",\"blocks\":1}}"));
    });
    using var client = new HttpClient(handler);
    var sut = new ChainInfo(new CryptoCoinHttpClient(client, maxRetryAttempts: 0));

    var result = await sut.AsyncFetch("BTC/TEST");

    result.acronym.Should().Be("BTC");
    result.blocks.Should().Be(1);
  }

  [Fact]
  public async Task TickerInfo_AsyncFetch_UsesConfiguredGetUriAndDeserializesPayload()
  {
    var handler = new DelegateHandler((request, _) =>
    {
      request.Method.Should().Be(HttpMethod.Get);
      request.RequestUri!.AbsoluteUri.Should().Be("https://blockchain.info/ticker");
      return Task.FromResult(CreateJsonResponse("{\"USD\":{\"symbol\":\"$\",\"last\":1.0}}"));
    });
    using var client = new HttpClient(handler);
    var sut = new TickerInfo(new CryptoCoinHttpClient(client, maxRetryAttempts: 0));

    var result = await sut.AsyncFetch();

    result.USD.symbol.Should().Be("$");
    result.USD.last.Should().Be(1.0f);
  }

  private static HttpResponseMessage CreateJsonResponse(string json) => new(HttpStatusCode.OK)
  {
    Content = new StringContent(json),
  };

  private sealed class DelegateHandler : HttpMessageHandler
  {
    private readonly Func<HttpRequestMessage, CancellationToken, Task<HttpResponseMessage>> handler;

    public DelegateHandler(Func<HttpRequestMessage, CancellationToken, Task<HttpResponseMessage>> handler)
    {
      this.handler = handler;
    }

    protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken) =>
      handler(request, cancellationToken);
  }
}