
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Globalization;
using System.Linq;
using System.Reflection;
using Itenso.TimePeriod;
using static ATAP.Utilities.CryptoCoin.ExtensionHelpers;
using static ATAP.Utilities.Enumeration.Utilities;

namespace ATAP.Utilities.CryptoCoin
{
    /*
    ///ToDO: (far future) localize the application using satellite assemblies for specific languages
    public class LocalizedDescriptionAttribute : DescriptionAttribute
    {
    private readonly string _resourceKey;
    private readonly ResourceManager _resource;
    public LocalizedDescriptionAttribute(string resourceKey, Type resourceType)
    {
    _resource = new ResourceManager(resourceType);
    _resourceKey = resourceKey;
    }
    
    public override string Description{
    get {
    string displayName = _resource.GetString(_resourceKey);
    return string.IsNullOrEmpty(displayName)
    ? string.Format("[[{0}]]", _resourceKey)
    : displayName;
    }
    }
    }
    */
    public static class ExtensionHelpers
    {
        
        public sealed class Symbol : Attribute, IAttribute<string>
        {
            public Symbol(string value) {
                Value = value;
            }

            public static implicit operator string(Symbol v) { return v.Value; }

            public string Value { get; }
        }
        
        public sealed class Algorithm : Attribute, IAttribute<string>
        {
            public Algorithm(string value) {
                Value = value;
            }

            public static implicit operator string(Algorithm v) { return v.Value; }

            public string Value { get; }
        }

        public sealed class Proof : Attribute, IAttribute<string>
        {
            public Proof(string value) {
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

    // ToDo: continue to add miner SW to this list
    public enum MinerSW
    {
        [Description("Claymore")]
        Claymore,
        [Description("ETHminer")]
        ETHminer,
        [Description("GENOIL")]
        GENOIL,
        [Description("XMRStak ")]
        XMRStak,
        [Description("WolfsMiner")]
        WolfsMiner,
        [Description("MoneroSpelunker")]
        MoneroSpelunker
    }

    public class BlockReward
    {
        double blockRewardPerBlock;

        public BlockReward(double blockRewardPerBlock)
        {
            this.blockRewardPerBlock = blockRewardPerBlock;
        }

        public double BlockRewardPerBlock { get { return blockRewardPerBlock; } set { blockRewardPerBlock = value; } }
    }

    public interface ICryptoCoinNetworkInfo
    {
        TimeBlock AvgBlockTime { get; set; }
        Coin Coin { get; set; }
        HashRate HashRate { get; set; }
    }

    public partial class CryptoCoinNetworkInfo : ICryptoCoinNetworkInfo
    {
        TimeBlock avgBlockTime;
        double blockRewardPerBlock;
        Coin coin;
        HashRate hashRate;

        public CryptoCoinNetworkInfo(Coin coin)
        {
            this.coin = coin;
        }
        public CryptoCoinNetworkInfo(Coin coin, HashRate hashRate, TimeBlock avgBlockTime, double blockRewardPerBlock)
        {
            this.coin = coin;
            this.hashRate = hashRate;
            this.avgBlockTime = avgBlockTime;
            this.blockRewardPerBlock = blockRewardPerBlock;
        }

        public static double AverageShareOfBlockRewardPerSpanFast(AverageShareOfBlockRewardDT data, TimeBlock timeBlock)
        {
            // normalize into minerHashRateAsAPercentOfTotal the MinerHashRate / NetworkHashRate using the TimeBlock of the Miner
            HashRate minerHashRateAsAPercentOfTotal = data.MinerHashRate / data.NetworkHashRate;
            // normalize the BlockRewardPerSpan to the same span the Miner HashRate span
            //ToDo Fix this calculation
            // normalize the BlockRewardPerSpan to the same span the network HashRate span
            double normalizedBlockCreationSpan = data.AverageBlockCreationSpan.Duration.Ticks /
                data.NetworkHashRate.HashRateTimeSpan.Duration.Ticks;
            double normalizedBlockRewardPerSpan = data.BlockRewardPerBlock /
                (data.AverageBlockCreationSpan.Duration.Ticks *
                    normalizedBlockCreationSpan);
            // The number of block rewards found, on average, within a given TimeBlock, is number of blocks in the span, times the fraction of the NetworkHashRate contributed by the miner
            return normalizedBlockRewardPerSpan *
                (minerHashRateAsAPercentOfTotal.HashRatePerTimeSpan /
                    data.NetworkHashRate.HashRatePerTimeSpan);
        }
        public static double AverageShareOfBlockRewardPerSpanSafe(AverageShareOfBlockRewardDT data, TimeBlock timeSpan)
        {
            // ToDo: Add parameter checking
            return AverageShareOfBlockRewardPerSpanFast(data, timeSpan);
        }

        public TimeBlock AvgBlockTime { get => avgBlockTime; set => avgBlockTime = value; }
        public double BlockRewardPerBlock { get { return blockRewardPerBlock; } set { blockRewardPerBlock = value; } }
        public Coin Coin {
            get { return coin; }
            set { coin = value; }
        }
        public HashRate HashRate { get => hashRate; set => hashRate = value; }
    }

    public interface IHashRatesDict
    {
        Dictionary<Coin, HashRate> HashRates { get; set; }
    }

    public class HashRate
    {
        double hashRatePerTimeSpan;
        TimeBlock hashRateTimeSpan;

        public HashRate(double hashRatePerTimeSpan, TimeBlock hashRateSpan)
        {
            this.hashRatePerTimeSpan = hashRatePerTimeSpan;
            this.hashRateTimeSpan = hashRateSpan;
        }

        // overload operator -
        public static HashRate operator -(HashRate a, HashRate b)
        {
            if(a.hashRateTimeSpan == b.hashRateTimeSpan)
            {
                return new HashRate(a.hashRatePerTimeSpan - b.hashRatePerTimeSpan, a.hashRateTimeSpan);
            }
            else
            {
                return new HashRate(a.hashRatePerTimeSpan -
                    (b.hashRatePerTimeSpan *
                        (a.hashRateTimeSpan.Duration.Ticks /
                            b.hashRateTimeSpan.Duration.Ticks)),
                                    a.hashRateTimeSpan);
            }
        }

        // overload operator *
        public static HashRate operator *(HashRate a, HashRate b)
        {
            if(a.hashRateTimeSpan == b.hashRateTimeSpan)
            {
                return new HashRate(a.hashRatePerTimeSpan * b.hashRatePerTimeSpan, a.hashRateTimeSpan);
            }
            else
            {
                return new HashRate(a.hashRatePerTimeSpan *
                    (b.hashRatePerTimeSpan *
                        (a.hashRateTimeSpan.Duration.Ticks /
                            b.hashRateTimeSpan.Duration.Ticks)),
                                    a.hashRateTimeSpan);
            }
        }
        // overload operator *
        public static HashRate operator /(HashRate a, HashRate b)
        {
            if(a.hashRateTimeSpan == b.hashRateTimeSpan)
            {
                return new HashRate(a.hashRatePerTimeSpan / b.hashRatePerTimeSpan, a.hashRateTimeSpan);
            }
            else
            {
                return new HashRate(a.hashRatePerTimeSpan /
                    (b.hashRatePerTimeSpan *
                        (a.hashRateTimeSpan.Duration.Ticks /
                            b.hashRateTimeSpan.Duration.Ticks)),
                                    a.hashRateTimeSpan);
            }
        }

        // overload operator +
        public static HashRate operator +(HashRate a, HashRate b)
        {
            if(a.hashRateTimeSpan == b.hashRateTimeSpan)
            {
                return new HashRate(a.hashRatePerTimeSpan + b.hashRatePerTimeSpan, a.hashRateTimeSpan);
            }
            else
            {
                return new HashRate(a.hashRatePerTimeSpan +
                    (b.hashRatePerTimeSpan *
                        (a.hashRateTimeSpan.Duration.Ticks /
                            b.hashRateTimeSpan.Duration.Ticks)),
                                    a.hashRateTimeSpan);
            }
        }

        public static HashRate ChangeTimeSpan(HashRate a, HashRate b)
        {
            // no parameter checking
            double normalizedTimeSpan = a.HashRateTimeSpan.Duration.Ticks / b.HashRateTimeSpan.Duration.Ticks;
            return new HashRate(a.hashRatePerTimeSpan *
                (a.hashRateTimeSpan.Duration.Ticks /
                    b.hashRateTimeSpan.Duration.Ticks),
                                a.hashRateTimeSpan);
        }

        public double HashRatePerTimeSpan { get { return hashRatePerTimeSpan; } set { hashRatePerTimeSpan = value; } }
        public TimeBlock HashRateTimeSpan { get { return hashRateTimeSpan; } set { hashRateTimeSpan = value; } }
    }

    public interface ICryptoCoinNetworkInfoBuilder
    {
        CryptoCoinNetworkInfo Build();
    }

    public class CryptoCoinNetworkInfoBuilder
    {
        TimeBlock avgBlockTime;
        double blockRewardPerBlock;
        Coin coin;
        HashRate hashRate;

        public CryptoCoinNetworkInfoBuilder() {
        }

        public CryptoCoinNetworkInfoBuilder AddAvgBlockTime(TimeBlock avgBlockTime)
        {
            this.avgBlockTime = avgBlockTime;
            return this;
        }
        public CryptoCoinNetworkInfoBuilder AddBlockReward(double blockRewardPerBlock)
        {
            this.blockRewardPerBlock = blockRewardPerBlock;
            return this;
        }
        public CryptoCoinNetworkInfoBuilder AddCoin(Coin coin)
        {
            this.coin = coin;
            return this;
        }

        public CryptoCoinNetworkInfoBuilder AddHashRate(HashRate hashRate)
        {
            this.hashRate = hashRate;
            return this;
        }
        public CryptoCoinNetworkInfo Build()
        {
            return new CryptoCoinNetworkInfo(coin, hashRate, avgBlockTime, blockRewardPerBlock);
        }
        public static CryptoCoinNetworkInfoBuilder CreateNew()
        {
            return new CryptoCoinNetworkInfoBuilder();
        }
    }

    public interface IAverageShareOfBlockRewardDT
    {
        TimeBlock AverageBlockCreationSpan { get; set; }
        double BlockRewardPerBlock { get; set; }
        TimeBlock Duration { get; set; }
        HashRate MinerHashRate { get; set; }
        HashRate NetworkHashRate { get; set; }
    }

    public interface IROAverageShareOfBlockRewardDT
    {
        TimeBlock AverageBlockCreationSpan { get; }
        double BlockRewardPerBlock { get; }
        TimeBlock Duration { get; }
        HashRate MinerHashRate { get; }
        HashRate NetworkHashRate { get; }
    }

    /* the minimum data fields needed to calculate one miners average share of total coins mined in a time period */
    public class AverageShareOfBlockRewardDT : IAverageShareOfBlockRewardDT, IROAverageShareOfBlockRewardDT
    {
        TimeBlock averageBlockCreationSpan;

        double blockRewardPerBlock;
        TimeBlock duration;
        HashRate minerHashRate;
        HashRate networkHashRate;

        public AverageShareOfBlockRewardDT(TimeBlock averageBlockCreationSpan, TimeBlock duration, HashRate minerHashRate, HashRate networkHashRate, double blockRewardPerBlock)
        {
            this.averageBlockCreationSpan = averageBlockCreationSpan;
            this.duration = duration;
            this.minerHashRate = minerHashRate;
            this.networkHashRate = networkHashRate;

            this.blockRewardPerBlock = blockRewardPerBlock;
        }

        public TimeBlock AverageBlockCreationSpan {
            get { return averageBlockCreationSpan; }
            set { averageBlockCreationSpan = value; }
        }
        public double BlockRewardPerBlock {
            get { return blockRewardPerBlock; }
            set { blockRewardPerBlock = value; }
        }
        public TimeBlock Duration {
            get { return duration; }
            set { duration = value; }
        }
        public HashRate MinerHashRate {
            get { return minerHashRate; }
            set { minerHashRate = value; }
        }
        public HashRate NetworkHashRate {
            get { return networkHashRate; }
            set { networkHashRate = value; }
        }
    }

    public interface IFees
    {
        Fees Fees { get; set; }
    }

    public class Fees
    {
        double feeAsAPercent;

        public Fees()
        {
            feeAsAPercent = default(double);
        }
        public Fees(double feeAsAPercent)
        {
            this.feeAsAPercent = feeAsAPercent;
        }

        public override string ToString()
        {
            return $"{FeeAsAPercent}";
        }

        public double FeeAsAPercent { get => feeAsAPercent; set => feeAsAPercent = value; }
    }

    public class FeesConverter : ExpandableObjectConverter
    {
        public override bool CanConvertFrom(ITypeDescriptorContext context, Type sourceType)
        {
            if(sourceType == typeof(string))
            {
                return true;
            }
            return base.CanConvertFrom(context, sourceType);
        }
        public override bool CanConvertTo(ITypeDescriptorContext context, Type destinationType)
        {
            if(destinationType == typeof(string))
            {
                return true;
            }
            return base.CanConvertTo(context, destinationType);
        }
        public override object ConvertFrom(ITypeDescriptorContext
            context, CultureInfo culture, object value)
        {
            if(value == null)
            {
                return new Fees();
            }

            if(value is string)
            {
                double d;
                if(!double.TryParse(value as string, out d))
                {
                    throw new ArgumentException("Object is not a string of format double", "value");
                }

                return new Fees(d);
            }

            return base.ConvertFrom(context, culture, value);
        }
        public override object ConvertTo(ITypeDescriptorContext context, CultureInfo culture, object value, Type destinationType)
        {
            if(value != null)
            {
                if(!(value is Fees))
                {
                    throw new ArgumentException("Invalid object, is not a Fees", "value");
                }
            }

            if(destinationType == typeof(string))
            {
                if(value == null)
                {
                    return ((value as Fees).FeeAsAPercent).ToString();
                }
            }
            return base.ConvertTo(context, culture, value, destinationType);
        }
    }

    public interface IPowerConsumption
    {
        PowerConsumption PowerConsumption { get; set; }
    }

    public class PowerConsumption
    {
        TimeSpan period;
        double watts;

        public PowerConsumption()
        {
            this.watts = default(double);
            this.period = default(TimeSpan);
        }
        public PowerConsumption(double w, TimeSpan period)
        {
            this.watts = w;
            this.period = period;
        }

        public override string ToString() {
            return $"{this.watts}-{this.period}";
        }

        public TimeSpan Period { get => period; set => period = value; }
        public double Watts { get => watts; set => watts = value; }
    }

    public class PowerConsumptionConverter : ExpandableObjectConverter
    {
        public override bool CanConvertFrom(
            ITypeDescriptorContext context, Type sourceType)
        {
            if(sourceType == typeof(string))
            {
                return true;
            }
            return base.CanConvertFrom(context, sourceType);
        }

        public override bool CanConvertTo(
            ITypeDescriptorContext context, Type destinationType)
        {
            if(destinationType == typeof(string))
            {
                return true;
            }
            return base.CanConvertTo(context, destinationType);
        }

        public override object ConvertFrom(ITypeDescriptorContext
            context, CultureInfo culture, object value)
        {
            if(value == null)
            {
                return new PowerConsumption();
            }

            if(value is string)
            {
                double w;
                TimeSpan period;
                //ToDo better validation on string to be sure it conforms to  "double-TimeBlock"
                string[] s = ((string)value).Split('-');
                if(s.Length != 2 || !double.TryParse(s[0], out w) || !TimeSpan.TryParse(s[1], out period))
                {
                    throw new ArgumentException("Object is not a string of format double-int",
                                               "value");
                }

                return new PowerConsumption(w, period);
            }

            return base.ConvertFrom(context, culture, value);
        }

        public override object ConvertTo(
            ITypeDescriptorContext context,
            CultureInfo culture, object value, Type destinationType)
        {
            if(value != null)
            {
                if(!(value is PowerConsumption))
                {
                    throw new ArgumentException("Invalid object, is not a PowerConsumption", "value");
                }
            }

            if(destinationType == typeof(string))
            {
                if(value == null)
                {
                    return string.Empty;
                }

                PowerConsumption powerConsumption = (PowerConsumption)value;
                return powerConsumption.ToString();
            }
            return base.ConvertTo(context,
                                  culture,
                                  value,
                destinationType);
        }
    }

    public sealed class InterestingCoins
    {
        static readonly Lazy<InterestingCoins> lazy =
    new Lazy<InterestingCoins>(() => new InterestingCoins());

        public InterestingCoins()
        {
        }

        public static InterestingCoins Instance { get { return lazy.Value; } }
    }
}

//public class CryptoCoins
//{
//
//            //Coinname = coinname ?? throw new ArgumentNullException(nameof(coinname));
//            //Avgblocktime = avgblocktime == TimeBlock.Zero ? throw new ArgumentOutOfRangeException(nameof(avgblocktime)) : avgblocktime;
//            //Networkhashrate = networkhashrate == Decimal.Zero ? throw new ArgumentOutOfRangeException(nameof(networkhashrate)) : networkhashrate;
//            //Blockreward = blockreward == Decimal.Zero ? throw new ArgumentOutOfRangeException(nameof(blockreward)) : blockreward;
//            //Hashrate = hashrate == Decimal.Zero ? throw new ArgumentOutOfRangeException(nameof(hashrate)) : hashrate;
//        // provides an estimate of the probability


//    }
//public class CryptoCoinDifficulty
//{
//    string coinname;
//    string aPIfull;
//    public string Coinname { get => coinname; set => coinname = value; }
//    public string APIfull { get => aPIfull; set => aPIfull = value; }
//    public CryptoCoinDifficulty(string coinname, string aPIfull)
//    {
//        Coinname = coinname ?? throw new ArgumentNullException(nameof(coinname));
//        APIfull = aPIfull ?? throw new ArgumentNullException(nameof(aPIfull));
//    }
//    public static async Task<int> GetDifficultyFromAPI(string requestUri)
//    {
//        if (string.IsNullOrWhiteSpace(requestUri))
//        {
//            throw new ArgumentException("message", nameof(requestUri));
//        }
//        // TODO: add validation tests on the requestUri string to ensure it passes basic URI rules
//        var response = await HttpRequestFactory.Get(requestUri);
//        // TODO: throw appropriate exception if a bad response is received
//        // ToDo: parse response based on collection of requestUri rules
//        // This is for XMR stats
//        var rstr = response.ContentAsJson();
//        // parse the JSON
//        XMRMoneroblocksCoinStats stats = JsonConvert.DeserializeObject<XMRMoneroblocksCoinStats>(response.ContentAsJson());
//        int dif = stats.difficulty;
//        return dif;
//    }
//}

/*
public class LocalizedDescriptionAttribute : DescriptionAttribute
{
private readonly string _resourceKey;
private readonly ResourceManager _resource;
public LocalizedDescriptionAttribute(string resourceKey, Type resourceType)
{
_resource = new ResourceManager(resourceType);
_resourceKey = resourceKey;
}

public override string Description{
get {
string displayName = _resource.GetString(_resourceKey);
return string.IsNullOrEmpty(displayName)
? string.Format("[[{0}]]", _resourceKey)
: displayName;
}
}
}
*/

/** Read-only thread safe Lazy loaded Singleton Instance class with the minimum data fields needed to calculate one miners average share of total coins mined in a time period */
/*
public sealed class NTSP_AverageShareOfBlockRewardDT : AverageShareOfBlockRewardDT
{
    //static readonly Lazy<NTSP_NormalizedAverageShareOfEmittedCoins> lazy =
    //new Lazy<NTSP_NormalizedAverageShareOfEmittedCoins>(() => new NTSP_NormalizedAverageShareOfEmittedCoins());

    public NTSP_AverageShareOfBlockRewardDT(TimeBlock averageBlockCreationSpan, TimeBlock duration, HashRate minerHashRate, HashRate networkHashRate, double blockRewardPerBlock) :
      base(averageBlockCreationSpan, duration, minerHashRate, networkHashRate, blockRewardPerBlock)
    {
    }

    //public static NTSP_NormalizedAverageShareOfEmittedCoins Instance { get { return lazy.Value; } }
}
*/

// NormalizedAverageShareOfEmittedCoins is a set of properties/fields, aka a DS.
// NormalizedAverageShareOfEmittedCoinsDS_FromHTTPClient
// 


//public class FromJSON1
//{

//    public FromJSON1(string r)
//    {
//        async Task<FromJSON1> GetAsync(string requestUri)
//        {

//            //ToDO: Better validation on getter
//            if (string.IsNullOrWhiteSpace(requestUri))
//            {
//                //ToDo: Better error handling on the throw
//                throw new ArgumentException("message", nameof(requestUri));
//            }
//            // TODO: add validation tests on the requestUri string to ensure it passes basic URI rules
//            var response = await HttpRequestFactory.Get(requestUri);
//            // TODO: throw appropriate exception if a bad response is received
//            // ToDo: parse response based on collection of requestUri rules - generalize the conversion based on the enumerations
//            // This is for XMR stats
//            var rstr = response.ContentAsJson();
//            // parse the JSON
//            //ToDo: encapsulate the specific type to which the JSON returned by that specific URI can be Converted by the JSONConvert<specificType> into the method parameter
//            FromJSON1 stats = JsonConvert.DeserializeObject<FromJSON1>(response.ContentAsJson());

//            return stats;

//        }
//        //FromJSON1 t = await GetAsync("http://moneroblocks.info/api/get_stats/");
//        Difficulty = 1;
//        Height = 2;
//        HashRate = 3.0m;
//        Current_emission = 5;
//        Last_reward = 2;
//        Last_timestamp = 2;
//        ;
//    }


//public CryptoCoins.CoinStatsCryptoNote ConvertToCryptoNoteCoinStats()
//{
//        CryptoCoins.CoinStatsCryptoNote t = new CryptoCoins.CoinStatsCryptoNote(Coin.XMR, DateTime.Now, TimeBlock.Zero, TimeBlock.FromMinutes(1.00), HashRate, Last_reward, Difficulty);
//        return t;
//    }

