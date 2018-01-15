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
 var data = Encoding.ASCII.GetBytes(tcpRequestMessage);
                var socket = new TcpClient(host, port);
                var stream = socket.GetStream();
                // write the request async   
                await stream.WriteAsync(data, 0, data.Length, cancellationToken);
                byte[] buffer = new byte[maxResponseBufferSize];
                // read the response async   
                int numBytesRead = await stream.ReadAsync(buffer, 0, maxResponseBufferSize, cancellationToken);
                return buffer;
            });
        }
    }
}
