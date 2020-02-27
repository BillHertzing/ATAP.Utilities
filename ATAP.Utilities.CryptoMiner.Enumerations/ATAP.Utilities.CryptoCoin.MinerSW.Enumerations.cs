
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Text;

namespace ATAP.Utilities.CryptoMiner.Enumerations
{
    // ToDo: continue to add miner SW to this list
    //[JsonConverter(typeof(StringEnumConverter))]
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
