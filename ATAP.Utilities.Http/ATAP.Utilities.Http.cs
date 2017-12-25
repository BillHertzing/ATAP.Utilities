using Polly;
using Polly.Registry;
using System;
using System.Collections.Generic;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Threading.Tasks;

namespace ATAP.Utilities.Http
{

    public sealed class SingletonWebGet {
        static readonly Lazy<SingletonWebGet> lazy = new Lazy<SingletonWebGet>(() => new SingletonWebGet());
        HttpClient httpClient;

        SingletonWebGet() {
            httpClient = new HttpClient();
        }

        static SingletonWebGet SingleInstanceOfWebGet { get { return lazy.Value; } }

        public static async Task<HttpResponseMessage> AsyncFetch(Policy policy, HttpRequestMessage httpRequestMessage) {
            return await policy.ExecuteAsync(async () => {
                return await SingletonWebGet.SingleInstanceOfWebGet.httpClient.SendAsync(httpRequestMessage);
            });
        }
    }

    public interface IHttpRequestMessageBuilder {
        HttpRequestMessage Build();
    }

    public class HttpRequestMessageBuilder : IHttpRequestMessageBuilder {
        string acceptHeader;
        string bearerToken;
        HttpContent content;
        // The HttpRequestHeaders are a System.Collections.Specialized.NameValueCollection() with a ADD(string,string) method
        HttpRequestHeaders httpRequestHeaders;
        HttpMethod method;
        Uri requestUri;

        public HttpRequestMessageBuilder() {
        }

        public HttpRequestMessageBuilder AddAcceptHeader(string acceptHeader) {
            this.acceptHeader = acceptHeader;
            return this;
        }
        public HttpRequestMessageBuilder AddBearerToken(string bearerToken) {
            this.bearerToken = bearerToken;
            return this;
        }
        public HttpRequestMessageBuilder AddContent(HttpContent content) {
            this.content = content;
            return this;
        }
        // Figure out some way to replace all of the headers with a new 
        //public HttpRequestMessageBuilder AddHeaders(HttpRequestMessage httpRequestMessage)
        //{
        //    foreach(var h in httpRequestMessage.Headers) { switch(h.Key) { defaulthttpRequestHeaders[h.Key] = h.Value; break; } }
        //    httpRequestHeaders = httpRequestHeaders;
        //    return this;
        //}
        public HttpRequestMessageBuilder AddMethod(HttpMethod method) {
            this.method = method;
            return this;
        }
        public HttpRequestMessageBuilder AddRequestUri(Uri requestUri) {
            this.requestUri = requestUri;
            return this;
        }
        public HttpRequestMessage Build() {
            HttpRequestMessage hrm = new HttpRequestMessage(method, requestUri);
            if (content != default(HttpContent)) {
                hrm.Content = content;
            };
            // ToDo Figure out how to replace the entire HttpRequestHeaders
            // if (httpRequestHeaders != default(HttpRequestHeaders) { hrm.Headers = httpRequestHeaders; }
            if (bearerToken != default(string)) {
                hrm.Headers.Authorization = new AuthenticationHeaderValue("Bearer", bearerToken);
            };
            //ToDo: further research, is .Headers.Accept.Clear() needed on a newly created HttpRequestMessage?
            hrm.Headers.Accept.Clear();
            if (acceptHeader != default(string)) {
                hrm.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue(acceptHeader));
            };
            return hrm;
        }
        public static HttpRequestMessageBuilder CreateNew() {
            return new HttpRequestMessageBuilder();
        }
    }

    public abstract class WebGet<TResult> {
        public WebGet(Policy policy, HttpRequestMessage httpRequestMessage) {
            Policy = policy;
            HttpRequestMessage = httpRequestMessage;
        }

        public virtual Task<TResult> FetchAsync(string str) {
            throw new NotImplementedException("Abstract class method called");
        }

        public virtual async Task<HttpResponseMessage> FetchAsync(Policy policy, HttpRequestMessage httpRequestMessage) {
            return await SingletonWebGet.AsyncFetch(policy, httpRequestMessage);
        }

        public virtual async Task<HttpResponseMessage> GetAsync() {
            return await SingletonWebGet.AsyncFetch(Policy, HttpRequestMessage);
        }

        public HttpRequestMessage HttpRequestMessage { get; set; }

        public Policy Policy { get; set; }
    }

    public class GenericWebGet : WebGet<HttpResponseMessage> {
        public GenericWebGet(Policy policy, HttpRequestMessage httpRequestMessage) : base(policy, httpRequestMessage) {
        }
    }


    /*
    // Within an application, there should only be one static instance of a HTPClient. This class provides that, and a set of static async tasks to interact with it.
    public interface IWebGet
    {
        Task<T> ASyncWebGetFast<T>(IWebGetRegistryKey reqID);
        Task<string> ASyncWebGetFast(IWebGetRegistryKey reqID);
        Task<string> ASyncWebGetFast(Policy p, HttpRequestMessage httpRequestMessage);
        Task<T> AsyncWebGetSafe<T>(IWebGetRegistryKey reqID);
        Task<T> WebGetFast<T>(IWebGetRegistryKey reqID);

        List<HttpStatusCode> HttpStatusCodesWorthRetrying { get; set; }
        PolicyRegistry PolicyRegistry { get; set; }
        IWebGetRegistry WebGetRegistry { get; set; }
    }
    public interface IWebGetRegistryValue
    {
        Policy Pol { get; set; }
        HttpRequestMessage Req { get; set; }
        WebGetHttpResponseHowToHandle Rsp { get; set; }
    }
    public interface IWebGetRegistryKey
    {
        string RegistryKey { get; set; }
    }
    public interface IHttpRequestMessageBuilder
    {
        HttpRequestMessage Build();
    }

    public interface IWebGetRegistry
    {
        void Add(IWebGetRegistryKey webGetRegistryKey, IWebGetRegistryKey webGetRegistryValue);

        Dictionary<IWebGetRegistryKey, IWebGetRegistryKey> Registry { get; set; }
    }
    */
}
