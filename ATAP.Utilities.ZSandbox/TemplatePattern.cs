using System;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace ATAP.Utilities.ZSandbox {
    public class Container2 {
        FT_CN _fT_CN;
        FT_CU _fT_CU;
        SolveAndStoreOD_AST1 _solveAndStoreOD_AST1;

        public Container2(SolveAndStoreOD_AST1 solveAndStoreOD_AST1, FT_CN fT_CN, FT_CU fT_CU) {
            _solveAndStoreOD_AST1 = solveAndStoreOD_AST1;
            _fT_CN = fT_CN;
            _fT_CU = fT_CU;
            //FT[] _FTColl = { _fT_CN, _fT_CU };
        }

        public FT_CN FT_CN { get => _fT_CN; set => _fT_CN = value; }

        public FT_CU FT_CU { get => _fT_CU; set => _fT_CU = value; }

        public SolveAndStoreOD_AST1 SolveAndStoreOD_AST1 { get => _solveAndStoreOD_AST1; set => _solveAndStoreOD_AST1 =
            value; }

        public class SolveAndStoreOD_ : SolveAndStoreOD<string, (string, string)> {
            Container _parent;
            Dictionary<string, decimal> _results;

            public SolveAndStoreOD_(Container parent, Dictionary<string, decimal> results) {
                _parent = parent;
                _results = results;
            }

            public override void SolveAndStore(string store, ((double, TimeSpan), string, string) solve) {
                var cn = _parent.FT_CN.GetIt(solve.Item2)
                             .Result;
                var cu = _parent.FT_CU.GetIt(solve.Item3)
                             .Result;
                var cfg = solve.Item1;
                _results[store] =
            
            }

            public Dictionary<string, decimal> Results { get => _results; set => _results =
                value; }
        }
    }

    public class FT_CU : FT<string, decimal> {
        public FT_CU(string uri) : base(uri) {
        }

        public override Task<decimal> GetIt(string p1) {
            throw new NotImplementedException();
        }
    }

    public class Container {
        FT_CN _fT_CN;
        SolveAndStoreOD_AST1 _solveAndStoreOD_AST1;

        public Container(SolveAndStoreOD_AST1 solveAndStoreOD_AST1, FT_CN fT_CN) {
            _solveAndStoreOD_AST1 = solveAndStoreOD_AST1;
            _fT_CN = fT_CN;
        }

        public FT_CN FT_CN { get => _fT_CN; set => _fT_CN = value; }

        public SolveAndStoreOD_AST1 SolveAndStoreOD_AST1 { get => _solveAndStoreOD_AST1; set => _solveAndStoreOD_AST1 =
            value; }
    }

    public class SolveAndStoreOD_AST1 : SolveAndStoreOD<string, string> {
        Container _parent;
        Dictionary<string, (double, double, TimeSpan)> _results;

        public SolveAndStoreOD_AST1(Container parent, Dictionary<string, (double, double, TimeSpan)> results) {
            _parent = parent;
            _results = results;
        }

        public override void SolveAndStore(string store, string solve) {
            _results[store] = _parent.FT_CN.GetIt(solve)
                                  .Result;
        }

        public Dictionary<string, (double, double, TimeSpan)> Results { get => _results; set => _results =
            value; }
    }

    public class FT_CN : FT<string, (double, double, TimeSpan)> {
        public FT_CN(string uri) : base(uri) {
        }

        public override Task<(double, double, TimeSpan)> GetIt(string p1) {
            throw new NotImplementedException();
        }
    }

    public abstract class FT<TFetchIn, TFetchResult> {
        string _uRI;

        public FT(string uri) {
            _uRI = uri;
        }

        public abstract Task<TFetchResult> GetIt(TFetchIn p1);

        public string URI { get => _uRI; set => _uRI = value; }
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

        public void TemplateMethod() {
            TStoreP store;
            TSolveP solve;
            SolveAndStore(store, solve);
        }
    }
}
