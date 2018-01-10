using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using ATAP.Utilities.CryptoCoin;


namespace ATAP.Utilities.ZSandbox {

    public class Container2 {
        public ChainInfo ChainInfo;
        public TickerInfo TickerInfo;
        public SolveAndStoreOD_2T SolveAndStoreOD;

        public Container2(SolveAndStoreOD_2T solveAndStoreOD, ChainInfo chainInfo, TickerInfo tickerInfo) {
            SolveAndStoreOD = solveAndStoreOD;
            ChainInfo = chainInfo;
            TickerInfo = tickerInfo;
            //FT[] _FTColl = { _fT_CN, _fT_CU };
        }



        public class SolveAndStoreOD_2T : SolveAndStoreOD<string, decimal> {
            Container2 _parent;
            Dictionary<string, decimal> Results;

            public SolveAndStoreOD_2T(Container2 parent, Dictionary<string, decimal> results) {
                _parent = parent;
                Results = results;
            }

            public override void SolveAndStore(string store, decimal solve) {
                var cn = _parent.ChainInfo.GetAsync("BTC")
                             .Result;
                var cu = _parent.TickerInfo.GetAsync()
                             .Result;
                decimal HR;

                decimal PR = decimal.TryParse(cn.hashrate,out HR) ? HR * (decimal)(cu.USD.last) : 0m;
                //_results[store] =


            }
        }
    }


    public class Container {
        public TickerInfo TickerInfo;
        public SolveAndStoreOD_TickerInfo SolveAndStoreOD_TickerInfo;

        public Container(SolveAndStoreOD_TickerInfo solveAndStoreOD, TickerInfo tickerInfo) {
            SolveAndStoreOD_TickerInfo = solveAndStoreOD;
            TickerInfo = tickerInfo;
        }

    }

    public class SolveAndStoreOD_TickerInfo : SolveAndStoreOD<string, blockChainInfo_ticker> {
        Container _parent;
        Dictionary<string, blockChainInfo_ticker> Results;

        public SolveAndStoreOD_TickerInfo(Container parent, Dictionary<string, blockChainInfo_ticker> results) {
            _parent = parent;
            Results = results;
        }

        public override void SolveAndStore(string store, blockChainInfo_ticker solve) {
            Results[store] = _parent.TickerInfo.GetAsync()
                                  .Result;
        }

    }



    public class SolveAndStoreOD_ST2 : SolveAndStoreOD<string, int> {
        Dictionary<string, (string, int)> _results;

        public SolveAndStoreOD_ST2(Dictionary<string, (string, int)> results) {
            _results = results;
        }

        public override void SolveAndStore(string store, int solve) {
            _results[store] = (solve.ToString(), solve);
        }

        public Dictionary<string, (string, int)> Results { get => _results; set => _results =
            value; }
    }

    public class SolveAndStoreOD_ST1 : SolveAndStoreOD<string, (string, int)> {
        Dictionary<string, (string, int)> _results;

        public SolveAndStoreOD_ST1(Dictionary<string, (string, int)> results) {
            _results = results;
        }

        public override void SolveAndStore(string store, (string, int) solve) {
            _results[store] = solve;
        }

        public Dictionary<string, (string, int)> Results { get => _results; set => _results =
            value; }
    }

    public class SolveAndStoreOD_int : SolveAndStoreOD<int, int> {
        int _results;

        public SolveAndStoreOD_int(int results) {
            _results = results;
        }

        public override void SolveAndStore(int store, int solve) {
            _results = solve;
        }

        public int Results { get => _results; set => _results = value; }
    }

    public class SolveAndStoreOD_intAr : SolveAndStoreOD<int, int> {
        int[] _results;

        public SolveAndStoreOD_intAr(int[] results) {
            _results = results;
        }

        public override void SolveAndStore(int store, int solve) {
            _results[store] = solve;
        }

        public int[] Results { get => _results; set => _results = value; }
    }

    public abstract class SolveAndStoreOD<TStoreP, TSolveP> {
        public abstract void SolveAndStore(TStoreP store, TSolveP solve);

        public void TemplateMethod(TStoreP store, TSolveP solve) {
            SolveAndStore(store, solve);
        }
    }
}
