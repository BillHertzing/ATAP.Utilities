using System;
using System.Collections.Generic;
using System.Net;
using System.Text;
using System.Threading.Tasks;

namespace ATAP.Utilities.CryptoCoin
{
    public abstract class ClaymoreMinerProcess : MinerProcess
    {
        public ClaymoreMinerProcess(ClaymoreMinerSW computerSoftwareProgram, params object[] arguments) : base(computerSoftwareProgram, arguments)
        {
        }


        public override async Task<IMinerStatus> StatusFetchAsync()
        {
            //var DUalStr = "{\"id\": 0, \"result\": [\"10.2 - ETH\", \"4258\", \"50033;1249;0\", \"24583;25450\", \"1501011;2571;0\", \"737502;763509\", \"68;100;81;100\", \"eth-us-east1.nanopool.org:9999;sia-us-east1.nanopool.org:7777\", \"0;2;0;2\"], \"error\": null}";
            //var msorigianlZEC = "{\"id\": 0, \"error\": null, \"result\": [\"12.6 - ZEC\", \"1676\", \"352; 1300; 4\", \"175; 177\", \"0; 0; 0\", \"off; off\", \"81; 100\", \"zec - us - east1.nanopool.org:6633\", \"0; 2; 0; 0\"]}";
            //var ms = "{\"id\": 0, \"error\": null, \"result\": [\"12.6 - ZEC\", \"1676\", \"352; 1300; 4\", \"175; 177\", \"0; 0; 0\", \"off; off\", \"81; 100\", \"zec - us - east1.nanopool.org:6633\", \"0; 2; 0; 0\"]}";
            // ToDo: Make this error message better
            if (!(this.ComputerSoftwareProgram.HasAPI && this.ComputerSoftwareProgram.HasConfigurationSettings)) throw new NotImplementedException("This software does not implement StatusFetchAsync.");
            // ToDo: decide if localhost, or IPV4 127.0.0.1, or IPV6, is better here
            //var host = "localhost";
            var host = Dns.GetHostName();
            // ToDo: Look for a more elegant way to get the API port
            //this.ConfigurationSettings.Keys
            var port = 21200;
            //ToDo: Determine if the claymore miner SW API message should be stored in a text file
            var message = "{\"id\":0,\"jsonrpc\":\"2.0\",\"method\":\"miner_getstat1\"}";
            byte[] responsebuffer = new byte[Tcp.Tcp.defaultMaxResponseBufferSize];
            // ToDo figure out what to do about exceptions and policies  let exceptions bubble up?
            // If there is no process listening on the port, there will be an exception
            //ToDo add a cancellation token
            //ToDo:  better exception handling
            
            try
            {
                responsebuffer = await Tcp.Tcp.FetchAsync(host, port, message);
            }
            catch (Exception)
            {

                throw;
            }
            // remove trailing NULL characters from end of the string after converting the response buffer to ASCII
            string str = Encoding.ASCII.GetString(responsebuffer).TrimEnd('\0');
            return new ClaymoreMinerStatus(str);
        }

    }
    public class ClaymoreZECMinerProcess : ClaymoreMinerProcess
    {
        public ClaymoreZECMinerProcess(ClaymoreZECMinerSW computerSoftwareProgram, params object[] arguments) : base(computerSoftwareProgram, arguments)
        {
        }
    }

    public class ClaymoreETHDualMinerProcess : ClaymoreMinerProcess
    {
        public ClaymoreETHDualMinerProcess(ClaymoreETHDualMinerSW computerSoftwareProgram, params object[] arguments) : base(computerSoftwareProgram, arguments)
        {
        }

    }
}
