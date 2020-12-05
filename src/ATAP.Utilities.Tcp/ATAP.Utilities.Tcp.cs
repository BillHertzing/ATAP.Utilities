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
        public static int defaultMaxResponseBufferSize = 1024;

        public static async Task<byte[]> FetchAsync(string host, int port, string tcpRequestMessage)
        {
            return await FetchAsync(Policy.NoOpAsync(),
                                    host,
                                    port,
                                    tcpRequestMessage,
                                    defaultMaxResponseBufferSize,
                                    CancellationToken.None);
        }
        public static async Task<byte[]> FetchAsync(Policy policy, string host, int port, string tcpRequestMessage)
        {
            return await FetchAsync(policy,
                                    host,
                                    port,
                                    tcpRequestMessage,
                                    defaultMaxResponseBufferSize,
                                    CancellationToken.None);
        }
        public static async Task<byte[]> FetchAsync(string host, int port, string tcpRequestMessage, CancellationToken cancellationToken)
        {
            return await FetchAsync(Policy.NoOp(),
                                    host,
                                    port,
                                    tcpRequestMessage,
                                    defaultMaxResponseBufferSize,
                                    cancellationToken);
        }
        public static async Task<byte[]> FetchAsync(Policy policy, string host, int port, string tcpRequestMessage, int maxResponseBufferSize, CancellationToken cancellationToken)
        {
            return await policy.ExecuteAsync(async() =>
            {
                // let every exception in this method bubble up
                //ToDo: Support other encodings?
                // assume the tcpRequestMessage is an ASCII encoded string, and convert it to a byte array
 var data = Encoding.ASCII.GetBytes(tcpRequestMessage);
                // In particular, this will thor an exception if there is no listener on this host/port combination
                var socket = new TcpClient(host, port);
                var stream = socket.GetStream();
                // write the request async   
                await stream.WriteAsync(data, 0, data.Length, cancellationToken);
                // The write has returned at this point, and no exception, so go and await to read the response.
                byte[] rawReadBuffer = new byte[maxResponseBufferSize];
                // read the response async   
                int numBytesRead = await stream.ReadAsync(rawReadBuffer, 0, maxResponseBufferSize, cancellationToken);
                // ToDo: figure out how to read responses that are larger than maxResponseBufferSize, or at least indicate to the calling program that there may be more data remaining
                byte[] responseBuffer = new byte[numBytesRead];
                // return just the number of bytes read from the stream
                Buffer.BlockCopy(rawReadBuffer, 0, responseBuffer, 0, numBytesRead);
                return responseBuffer;
            });
        }
    }
}
