using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Text;
using static ATAP.Utilities.CryptoCoin.Enumerations.ExtensionHelpers;
using static ATAP.Utilities.Enumeration.Utilities;

namespace ATAP.Utilities.CryptoCoin.Enumerations
{
    public static class ExtensionHelpers
    {

        public sealed class Symbol : Attribute, IAttribute<string>
        {
            public Symbol(string value)
            {
                Value = value;
            }

            public static implicit operator string(Symbol v) { return v.Value; }

            public string Value { get; }
        }

        public sealed class Algorithm : Attribute, IAttribute<string>
        {
            public Algorithm(string value)
            {
                Value = value;
            }

            public static implicit operator string(Algorithm v) { return v.Value; }

            public string Value { get; }
        }

        public sealed class Proof : Attribute, IAttribute<string>
        {
            public Proof(string value)
            {
                Value = value;
            }

            public static implicit operator string(Proof v) { return v.Value; }

            public string Value { get; }
        }
    }

    public enum Proofs
    {
        //[LocalizedDescription("Work", typeof(Resource))]
        [Description("Work")]
        Work,
        [Description("Stake")]
        Stake,
        [Description("Burn")]
        Burn,
        [Description("Activity")]
        Activity,
        [Description("Capacity")]
        Capacity
    }

    // ToDo: automate the creation of the Algorithm enumeration and its attributes based on ???
    // ToDo: it will require the DLL version created to be part of versioning
    // RoDo: it require any changes be integrated into version control.
    public enum Algorithms
    {
        [Description("Casper")]
        Casper,
        [Description("CryptoNote")]
        CryptoNote,
        [Description("Hashcash")]
        Hashcash,
        [Description("Lyra2RE")]
        Lyra2RE,
        [Description("ZeroCoin")]
        ZeroCoin
    }

    // ToDo: automate the creation of the enumeration and its attributes based on the data stored in the GIT project https://github.com/crypti/cryptocurrencies.git. Also look at https://stackoverflow.com/questions/725043/dynamic-enum-in-c-sharp for making the list dynamic
    // ToDo: it will require the DLL version created to be part of versioning
    // RoDo: it require any changes be integrated into version control.
    // There are over 1500+ different documented coins so far
    public enum Coin
    {
        [Symbol("BCN")]
        [Description("Bytecoin")]
        [Proof("Work")]
        [Algorithm("CryptoNote")]
        BCN,
        [Proof("Work")]
        [Algorithm("Hashcash")]
        [Symbol("BTC")]
        [Description("BitCoin")]
        BTC,
        [Symbol("ETH")]
        [Description("Ethereum")]
        [Proof("Stake")]
        [Algorithm("Casper")]
        ETH,
        [Symbol("DSH")]
        [Description("Dashcoin ")]
        [Proof("Work")]
        [Algorithm("CryptoNote")]
        DSH,
        [Symbol("XMR")]
        [Description("Monero")]
        [Proof("Work")]
        [Algorithm("CryptoNote")]
        XMR,
        [Algorithm("ZeroCoin")]
        [Symbol("ZEC")]
        [Description("ZCoin")]
        ZEC
    }

}
