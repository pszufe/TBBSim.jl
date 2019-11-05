using DataFrames, Parameters, CSV, Distributed

#install via:
# using Pkg; Pkg.add("https://github.com/pszufe/TBBSim.jl.git")
using TBBSim

addprocs(2) #change to the desired number of processes
@everywhere using DataFrames, Parameters, CSV, Distributed
@everywhere using TBBSim


p = MarketParams(nA=10,home_ln_avg=6.5,home_ln_std=0.10,nB=100)
pp = (nH=[70,80,90,100,110,120,130,140], buyer_value_p=[0.9,0.95,1.0,1.05,1.1,1.15,1.2,1.25], buyer_value_std=[0.05,0.1,0.15,0.2,0.25,0.30])
vals = vec(collect(Base.Iterators.product(pp.nH,pp.buyer_value_p,pp.buyer_value_std)))
sweep = [MarketParams(p,Dict(:nH => val[1], :buyer_value_p=>val[2], :buyer_value_std=>val[3] )) for val in vals]


big_res = @distributed (append!) for i in 1:length(sweep)
    println("############ sweep=$i ")
    res = runsims(sweep[i],nm=30,nN=10)
    tablerow = res_agg(res,sweep[i];sim_params_id=i)
    CSV.write("TAB_2$i", tablerow,delim='\t')
    tablerow
end


println("All OK")
# write the aggregated result to a file
CSV.write("tbb_sim_res_2.txt", big_res,delim='\t')
# write the aggregated result to the standard output
CSV.write(stdout, big_res,delim='\t')
