using System;
using System.Linq;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Polly;

namespace ATAP.Utilities.Tcp
{
    
    public class Tcp
    {
        //
        // ToDo: Move into a TCP configuration section
        public static int defaultMaxResponseBufferSize = 1024;
        // ToDo: move into a resilience policy repository
        public static int maxRetryAttempts = 3;
        public static TimeSpan pauseBetweenFailures = TimeSpan.FromSeconds(2); 
        public static Policy retryPolicy = Policy
          .WaitAndRetryAsync(maxRetryAttempts, i => pauseBetweenFailures);

        public static async Task<byte[]> FetchAsync(string host, int port, string tcpRequestMessage, Encoding encoding = default, Policy policy = default, int maxResponseBufferSize = default, CancellationToken cancellationToken = default)
        {
            Encoding _encoding;
            if (encoding == default) {_encoding = new System.Text.UTF8Encoding();} else {_encoding = encoding;}
            Policy _policy;
            if (policy == default) {_policy = retryPolicy;} else {_policy = policy;}
            int _maxResponseBufferSize;
            if (maxResponseBufferSize == default) {_maxResponseBufferSize = defaultMaxResponseBufferSize;} else {_maxResponseBufferSize = maxResponseBufferSize;}
            CancellationToken _cancellationToken ;
            if (cancellationToken == default) {_cancellationToken = CancellationToken.None;} else {_cancellationToken = cancellationToken;}
            return await policy.FetchAsync(async() =>
            {
                // let every exception in this method bubble up
                // assume the tcpRequestMessage encoding supports converting to a byte array 
                // ToDo: add try catch to ensure the encoding passed will support conversion to a byte-array
                var data = _encoding.GetBytes(tcpRequestMessage);
                // ToDo: Add try/catch for the exception that gets thrown if there is no listener on this host/port combination
                var socket = new TcpClient(host, port);
                var stream = socket.GetStream();
                // write the request async 
                // ToDo: exception handling, and possibly a resilience policy?  
                await stream.WriteAsync(data, 0, data.Length, _cancellationToken);
                // The write has returned at this point, and no exception, so go and await to read the response.
                byte[] rawReadBuffer = new byte[_maxResponseBufferSize];
                // read the response async  
                int numBytesRead = await stream.ReadAsync(rawReadBuffer, 0, _maxResponseBufferSize, _cancellationToken);
                // ToDo: figure out how to read responses that are larger than maxResponseBufferSize, or at least indicate to the calling program that there may be more data remaining
                byte[] responseBuffer = new byte[numBytesRead];
                // return just the number of bytes read from the stream
                Buffer.BlockCopy(rawReadBuffer, 0, responseBuffer, 0, numBytesRead);
                return responseBuffer;
            });
        }
    }
    
}
