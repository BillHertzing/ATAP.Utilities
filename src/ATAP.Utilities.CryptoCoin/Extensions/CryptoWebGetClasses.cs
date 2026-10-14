using System;
using System.Net;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;
using Newtonsoft.Json;
using Polly;
using Polly.Timeout;

namespace ATAP.Utilities.CryptoCoin
{
  public interface ICryptoCoinHttpClient
  {
    Task<HttpResponseMessage> GetAsync(Uri requestUri, CancellationToken cancellationToken = default);
  }

  public sealed class CryptoCoinHttpClient : ICryptoCoinHttpClient
  {
    private static readonly HttpClient SharedHttpClient = new(new SocketsHttpHandler
    {
      PooledConnectionLifetime = TimeSpan.FromMinutes(15),
    });

    private readonly HttpClient httpClient;
    private readonly IAsyncPolicy<HttpResponseMessage> resiliencePolicy;

    public CryptoCoinHttpClient()
      : this(SharedHttpClient, maxRetryAttempts: 3, timeout: TimeSpan.FromSeconds(30))
    {
    }

    public CryptoCoinHttpClient(HttpClient httpClient, int maxRetryAttempts = 3, TimeSpan? timeout = null)
    {
      this.httpClient = httpClient ?? throw new ArgumentNullException(nameof(httpClient));
      if (maxRetryAttempts < 0)
      {
        throw new ArgumentOutOfRangeException(nameof(maxRetryAttempts));
      }

      var requestTimeout = timeout ?? TimeSpan.FromSeconds(30);
      if (requestTimeout <= TimeSpan.Zero)
      {
        throw new ArgumentOutOfRangeException(nameof(timeout));
      }

      var retryPolicy = Policy<HttpResponseMessage>
        .Handle<HttpRequestException>()
        .Or<TimeoutRejectedException>()
        .OrResult(response => response.StatusCode == HttpStatusCode.RequestTimeout || (int)response.StatusCode >= 500)
        .WaitAndRetryAsync(maxRetryAttempts, retryAttempt => TimeSpan.FromMilliseconds(100 * retryAttempt));
      var timeoutPolicy = Policy.TimeoutAsync<HttpResponseMessage>(requestTimeout);
      resiliencePolicy = Policy.WrapAsync(timeoutPolicy, retryPolicy);
    }

    public Task<HttpResponseMessage> GetAsync(Uri requestUri, CancellationToken cancellationToken = default)
    {
      ArgumentNullException.ThrowIfNull(requestUri);
      if (!requestUri.IsAbsoluteUri)
      {
        throw new ArgumentException("The request URI must be absolute.", nameof(requestUri));
      }

      return resiliencePolicy.ExecuteAsync(
        async token =>
        {
          using var request = new HttpRequestMessage(HttpMethod.Get, requestUri);
          return await httpClient.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, token).ConfigureAwait(false);
        },
        cancellationToken);
    }
  }

  public class ChainInfo
  {
    private static readonly Uri ChainInfoBaseUri = new("https://chain.so/api/v2/get_info/");
    private readonly ICryptoCoinHttpClient httpClient;

    public ChainInfo()
      : this(new CryptoCoinHttpClient())
    {
    }

    public ChainInfo(ICryptoCoinHttpClient httpClient)
    {
      this.httpClient = httpClient ?? throw new ArgumentNullException(nameof(httpClient));
    }

    public async Task<chain_so_api_v2_get_info_Data> AsyncFetch(string coin, CancellationToken cancellationToken = default)
    {
      if (string.IsNullOrWhiteSpace(coin))
      {
        throw new ArgumentException("A coin symbol is required.", nameof(coin));
      }

      var requestUri = new Uri(ChainInfoBaseUri, Uri.EscapeDataString(coin));
      using var response = await httpClient.GetAsync(requestUri, cancellationToken).ConfigureAwait(false);
      response.EnsureSuccessStatusCode();
      var data = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);
      return string.IsNullOrEmpty(data)
        ? default
        : JsonConvert.DeserializeObject<chain_so_api_v2_get_info>(data)?.data;
    }
  }

  public class TickerInfo
  {
    private static readonly Uri TickerUri = new("https://blockchain.info/ticker");
    private readonly ICryptoCoinHttpClient httpClient;

    public TickerInfo()
      : this(new CryptoCoinHttpClient())
    {
    }

    public TickerInfo(ICryptoCoinHttpClient httpClient)
    {
      this.httpClient = httpClient ?? throw new ArgumentNullException(nameof(httpClient));
    }

    public async Task<blockChainInfo_ticker> AsyncFetch(CancellationToken cancellationToken = default)
    {
      using var response = await httpClient.GetAsync(TickerUri, cancellationToken).ConfigureAwait(false);
      response.EnsureSuccessStatusCode();
      var data = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);
      return string.IsNullOrEmpty(data)
        ? default
        : JsonConvert.DeserializeObject<blockChainInfo_ticker>(data);
    }
  }
    //https://chain.so//api/v2/get_info/BTC
    public class chain_so_api_v2_get_info {
        public chain_so_api_v2_get_info_Data data { get; set; }

        public string status { get; set; }
    }

    public class chain_so_api_v2_get_info_Data {
        public string acronym { get; set; }

        public int blocks { get; set; }

        public string hashrate { get; set; }

        public string mining_difficulty { get; set; }

        public string name { get; set; }

        public string network { get; set; }

        public string price { get; set; }

        public string price_base { get; set; }

        public int price_update_time { get; set; }

        public string symbol_htmlcode { get; set; }

        public int unconfirmed_txs { get; set; }

        public string url { get; set; }
    }

    //https://blockchain.info/ticker
    public class blockChainInfo_ticker {
        public AUD AUD { get; set; }
        public BRL BRL { get; set; }
        public CAD CAD { get; set; }
        public CHF CHF { get; set; }
        public CLP CLP { get; set; }
        public CNY CNY { get; set; }
        public DKK DKK { get; set; }
        public EUR EUR { get; set; }
        public GBP GBP { get; set; }
        public HKD HKD { get; set; }
        public ISK ISK { get; set; }
        public JPY JPY { get; set; }
        public KRW KRW { get; set; }
        public NZD NZD { get; set; }
        public PLN PLN { get; set; }
        public RUB RUB { get; set; }
        public SEK SEK { get; set; }
        public SGD SGD { get; set; }
        public THB THB { get; set; }
        public TWD TWD { get; set; }
        public USD USD { get; set; }
    }

    public class USD {
        public float _15m { get; set; }
        public float buy { get; set; }
        public float last { get; set; }
        public float sell { get; set; }
        public string symbol { get; set; }
    }

    public class JPY {
        public float _15m { get; set; }
        public float buy { get; set; }
        public float last { get; set; }
        public float sell { get; set; }
        public string symbol { get; set; }
    }

    public class CNY {
        public float _15m { get; set; }
        public float buy { get; set; }
        public float last { get; set; }
        public float sell { get; set; }
        public string symbol { get; set; }
    }

    public class SGD {
        public float _15m { get; set; }
        public float buy { get; set; }
        public float last { get; set; }
        public float sell { get; set; }
        public string symbol { get; set; }
    }

    public class HKD {
        public float _15m { get; set; }
        public float buy { get; set; }
        public float last { get; set; }
        public float sell { get; set; }
        public string symbol { get; set; }
    }

    public class CAD {
        public float _15m { get; set; }
        public float buy { get; set; }
        public float last { get; set; }
        public float sell { get; set; }
        public string symbol { get; set; }
    }

    public class NZD {
        public float _15m { get; set; }
        public float buy { get; set; }
        public float last { get; set; }
        public float sell { get; set; }
        public string symbol { get; set; }
    }

    public class AUD {
        public float _15m { get; set; }
        public float buy { get; set; }
        public float last { get; set; }
        public float sell { get; set; }
        public string symbol { get; set; }
    }

    public class CLP {
        public float _15m { get; set; }
        public float buy { get; set; }
        public float last { get; set; }
        public float sell { get; set; }
        public string symbol { get; set; }
    }

    public class GBP {
        public float _15m { get; set; }
        public float buy { get; set; }
        public float last { get; set; }
        public float sell { get; set; }
        public string symbol { get; set; }
    }

    public class DKK {
        public float _15m { get; set; }
        public float buy { get; set; }
        public float last { get; set; }
        public float sell { get; set; }
        public string symbol { get; set; }
    }

    public class SEK {
        public float _15m { get; set; }
        public float buy { get; set; }
        public float last { get; set; }
        public float sell { get; set; }
        public string symbol { get; set; }
    }

    public class ISK {
        public float _15m { get; set; }
        public float buy { get; set; }
        public float last { get; set; }
        public float sell { get; set; }
        public string symbol { get; set; }
    }

    public class CHF {
        public float _15m { get; set; }
        public float buy { get; set; }
        public float last { get; set; }
        public float sell { get; set; }
        public string symbol { get; set; }
    }

    public class BRL {
        public float _15m { get; set; }
        public float buy { get; set; }
        public float last { get; set; }
        public float sell { get; set; }
        public string symbol { get; set; }
    }

    public class EUR {
        public float _15m { get; set; }
        public float buy { get; set; }
        public float last { get; set; }
        public float sell { get; set; }
        public string symbol { get; set; }
    }

    public class RUB {
        public float _15m { get; set; }
        public float buy { get; set; }
        public float last { get; set; }
        public float sell { get; set; }
        public string symbol { get; set; }
    }

    public class PLN {
        public float _15m { get; set; }
        public float buy { get; set; }
        public float last { get; set; }
        public float sell { get; set; }
        public string symbol { get; set; }
    }

    public class THB {
        public float _15m { get; set; }
        public float buy { get; set; }
        public float last { get; set; }
        public float sell { get; set; }
        public string symbol { get; set; }
    }

    public class KRW {
        public float _15m { get; set; }
        public float buy { get; set; }
        public float last { get; set; }
        public float sell { get; set; }
        public string symbol { get; set; }
    }

    public class TWD {
        public float _15m { get; set; }
        public float buy { get; set; }
        public float last { get; set; }
        public float sell { get; set; }
        public string symbol { get; set; }
    }

}
