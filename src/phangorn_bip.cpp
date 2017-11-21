#include <Rcpp.h>
using namespace Rcpp;

// replacement for bip maybe more error tolerant slightly slower
// import: edge matrix, number of tips
// export: Descendants(x, 1:max(x$edge), "all")
// [[Rcpp::export]]
List bipCPP(IntegerMatrix orig, int nTips) {
    IntegerVector parent = orig( _, 0);
    IntegerVector children = orig( _, 1);
    int m = max(parent), j=0;
    // create list for results
    std::vector< std::vector<int> > out(m) ;
    std::vector<int> y;
    for(int i = 0; i<nTips; i++){
        out[i].push_back(i + 1L);
    }
    for(int i = 0; i<parent.size(); i++){
        j = parent[i] - 1L;
        if(children[i] > nTips){ 
            y = out[children[i] - 1L];
            out[j].insert( out[j].end(), y.begin(), y.end() );
        }
        else out[j].push_back(children[i]);
    }
    for(int i=0; i<m; ++i){
        sort(out[i].begin(), out[i].end());
    }
    return wrap(out);    // return the list
}

// bipCPP
RcppExport SEXP _phangorn_bipCPP(SEXP origSEXP, SEXP nTipsSEXP) {
BEGIN_RCPP
    Rcpp::RObject rcpp_result_gen;
    Rcpp::RNGScope rcpp_rngScope_gen;
    Rcpp::traits::input_parameter< IntegerMatrix >::type orig(origSEXP);
    Rcpp::traits::input_parameter< int >::type nTips(nTipsSEXP);
    rcpp_result_gen = Rcpp::wrap(bipCPP(orig, nTips));
    return rcpp_result_gen;
END_RCPP
}