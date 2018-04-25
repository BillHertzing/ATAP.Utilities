using Newtonsoft.Json;
using Newtonsoft.Json.Converters;
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Text;

namespace ATAP.Utilities.CryptoCoin
{
    // ToDo: continue to add miner SW to this list
    [JsonConverter(typeof(StringEnumConverter))]
    public enum MinerSWE
    {
        [Description("Claymore")]
        Claymore,
        [Description("ETHminer")]
        ETHMiner,
        [Description("GENOIL")]
        GENOIL,
        [Description("XMRStak ")]
        XMRStak,
        [Description("WolfsMiner")]
        WolfsMiner,
        [Description("MoneroSpelunker")]
        MoneroSpelunker
    }


}
