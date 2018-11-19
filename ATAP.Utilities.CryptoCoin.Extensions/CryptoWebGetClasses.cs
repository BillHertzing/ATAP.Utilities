using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;
using ATAP.Utilities.Http;
using Newtonsoft.Json;
using Polly;
using Polly.Timeout;

namespace ATAP.Utilities.CryptoCoin
{
    public class ChainInfo : WebGet<chain_so_api_v2_get_info_Data> {
        public ChainInfo() : base(Policy.TimeoutAsync(new TimeSpan(0, 0, 30),
                                              TimeoutStrategy.Optimistic),
                            HttpRequestMessageBuilder.CreateNew()
                                                                 .AddMethod(HttpMethod.Get)
                                                                 .AddRequestUri(new Uri("https://chain.so//api/v2/get_info/"))
                                                                 // .AddHeaders(ToDo);
                                                                 .Build()
        ) {
        }

        public ChainInfo(Policy policy) : base(policy,
                                               HttpRequestMessageBuilder.CreateNew()
                                                                 .AddMethod(HttpMethod.Get)
                                                                 .AddRequestUri(new Uri("https://chain.so//api/v2/get_info/"))
                                                                 // .AddHeaders(ToDo);
                                                                 .Build()) {
        }

        public async Task<chain_so_api_v2_get_info_Data> GetAsync(string coin) {
            UriBuilder uriBuilder = new UriBuilder(HttpRequestMessage.RequestUri);
            uriBuilder.Path += coin;
            HttpRequestMessage.RequestUri = uriBuilder.Uri;
            var httpResponseMessage = await SingletonHttpClient.AsyncFetch(Policy, HttpRequestMessage);
            var data = await httpResponseMessage.Content.ReadAsStringAsync();
            return string.IsNullOrEmpty(data) ?
                            default(chain_so_api_v2_get_info_Data) :
                            JsonConvert.DeserializeObject<chain_so_api_v2_get_info_Data>(data);
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

    public class TickerInfo : WebGet<blockChainInfo_ticker> {
        public TickerInfo() : base(Policy.TimeoutAsync(new TimeSpan(0, 0, 30),
                                              TimeoutStrategy.Optimistic),
            HttpRequestMessageBuilder.CreateNew()
                                                                 .AddMethod(HttpMethod.Get)
                                                                 .AddRequestUri(new Uri("https://blockchain.info/ticker"))
                                                                 // .AddHeaders(ToDo);
                                                                 .Build()
                                  ) {
        }

        public TickerInfo(Policy policy) : base(policy,
            HttpRequestMessageBuilder.CreateNew()
                                                                 .AddMethod(HttpMethod.Get)
                                                                 .AddRequestUri(new Uri("https://blockchain.info/ticker"))
                                                                 // .AddHeaders(ToDo);
                                                                 .Build()
                                  ) {
        }

        public new async Task<blockChainInfo_ticker> GetAsync() {
            UriBuilder uriBuilder = new UriBuilder(HttpRequestMessage.RequestUri);
            HttpRequestMessage.RequestUri = uriBuilder.Uri;
            var httpResponseMessage = await SingletonHttpClient.AsyncFetch(Policy, HttpRequestMessage);
            var data = await httpResponseMessage.Content.ReadAsStringAsync();
            return string.IsNullOrEmpty(data) ?
                            default(blockChainInfo_ticker) :
                            JsonConvert.DeserializeObject<blockChainInfo_ticker>(data);
        }
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
