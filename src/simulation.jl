function simulate!(market::Market;steps::Int=100,tbb=false,double_ending_price_premium::Union{Nothing,Float64}=nothing)
    for stepno in 1:steps
        if length(market.available_homes) == 0 || length(market.available_buyers) == 0
            break
        end
        for j in shuffle(collect(market.available_buyers))
            try_place_a_bid!(market, j, stepno, tbb, double_ending_price_premium)
        end
        if stepno < 3 continue end
        @assert (length(market.double_ended_home_buyer)==0) || double_ending_price_premium !=nothing
        for i in shuffle(collect(keys(market.double_ended_home_buyer)))
            try_process_sale!(market, i, stepno,double_ending_price_premium, true)
        end
        for i in shuffle(collect(market.available_homes))
            try_process_sale!(market, i, stepno,double_ending_price_premium, false)
        end
    end
    market.transactions
end


function try_place_a_bid!(market::Market, j::Int,stepno::Int,tbb::Bool, double_ending_price_premium::Union{Nothing,Float64})
    buyer = market.buyers[j]
    i = rand(market.available_homes)
    seller = market.homeowners[i]
    if !(i in buyer.seen_homes)
        push!(buyer.seen_homes, i)
        push!(seller.seen_by, j)
        best_other_bid = seller.r
        if length(seller.bids)>0
            best_other_bid, some_bidder = findmax(seller.bids)
            if some_bidder == j
                return #do not overbid yourself
            end
        end

        buyersvalue = buyer.v[i]
        if double_ending_price_premium != nothing && buyer.ak == seller.ak && !tbb
            buyersvalue *= (1+double_ending_price_premium)
        end

        if buyersvalue > seller.r+1
            bid = best_other_bid+1
            if double_ending_price_premium != nothing && buyer.ak == seller.ak && !tbb
                bid = buyersvalue-1
                if  (!(i in keys(market.double_ended_home_buyer)) ||
                        seller.bids[market.double_ended_home_buyer[i]] < bid) &&
                        !(j in values(market.double_ended_home_buyer))
                    market.double_ended_home_buyer[i] = j
                end
                #double ending --> bid highest possible amount
            else
                #bid = round(rand(Uniform(seller.r+1.,buyer.v[i])))
                if best_other_bid+1. >= buyersvalue-1
                    bid = buyersvalue-1
                else
                    if tbb
                        # has market info - will bid between other bid and her value
                        #bid = max(bid,best_other_bid+1)
                        bid = round((best_other_bid+buyersvalue)/2)
                    else
                        #has no market info - will overbid
                        #bid = round(rand(Uniform(best_other_bid+1.,buyer.v[i]-1)))
                        bid = round(rand(TriangularDist(seller.r,buyersvalue-1,buyersvalue-1)))
                    end
                end

            end
            #need to bid lower than the perceived property value
            @assert bid <= buyersvalue
            seller.bids[j]=bid
            push!(seller.bid_history,(j,bid))
            buyer.bids[i] = bid
            #seller.i==2 && println("Added bid $bid from j=$j for i=$i")
        end
    end
    if length(buyer.bids) >= 3
        #the buyer learns from the market and removes the worst bid
        #if it is below 1 std
        i_s = collect(keys(buyer.bids))
        filter!(i -> buyer.ak != market.homeowners[i].ak, i_s)
        if length(i_s) >= 3
            gains = [(buyer.v[i] - buyer.bids[i]) for i in i_s]
            amount, i_in_is = findmin(gains)
            if amount < mean(gains) - std(gains)
                @assert i_s[i_in_is] in keys(buyer.bids)
                delete!(buyer.bids, i_s[i_in_is])
                @assert j in keys(market.homeowners[i_s[i_in_is]].bids)
                delete!(market.homeowners[i_s[i_in_is]].bids, j)
                if get(market.double_ended_home_buyer, i_s[i_in_is], -1) == j
                    delete!(market.double_ended_home_buyer, i_s[i_in_is])
                end
            end
        end
    end
end


function try_process_sale!(market::Market, i::Int,stepno::Int,double_ending_price_premium::Union{Nothing,Float64},doubleend::Bool=false)
    seller = market.homeowners[i]
    length(seller.bids) == 0 && return nothing
    j::Int = -1
    if doubleend
        j = market.double_ended_home_buyer[i]
        #global m_debug = market
        #println("i=$i, j=$j, stepno=$stepno")
        best_bid = seller.bids[j]
    else
        best_bid, j = findmax(seller.bids)
    end
    @assert best_bid >= seller.r
    avg_real_val = mean(market.buyers[bj].v[i] for bj in market.available_buyers)
    if doubleend || (length(seller.bids) > rand((stepno>40 ? 0 : 4):(stepno>50 ? 1 : 8)) && best_bid >= avg_real_val*0.25)
        @assert i == seller.i
        delete!(market.available_homes, i)
        delete!(market.available_buyers, j)
        delete!(market.double_ended_home_buyer, i)
        for otherseller in market.homeowners
            if otherseller.i != i
                delete!(otherseller.bids, j)
            end
        end
        trans = Dict{Symbol,Union{Int,Float64,Bool,Missing}}(
            :step=>stepno,
            :i => i,
            :j => j,
            :k_s => market.homeowners[i].ak,
            :k_b => market.buyers[j].ak,
            :allow_de => double_ending_price_premium != nothing,
            :de_price_premium => something(double_ending_price_premium, missing),
            :seen_s=>length(market.homeowners[i].seen_by),
            :seen_b=>length(market.buyers[j].seen_homes),
            :cost_sa=>market.agents[market.homeowners[i].ak].cs,
            :cost_ba=>market.agents[market.buyers[j].ak].cb,
            :prov_sa=>market.agents[market.homeowners[i].ak].ds,
            :prov_ba=>market.agents[market.buyers[j].ak].db,
            :price_r=>market.homeowners[i].r,
            :price_v=>market.buyers[j].v[i],
            :double_ended=> double_ending_price_premium != nothing && (market.homeowners[i].ak==market.buyers[j].ak),
            :price=>best_bid
            )
        push!(market.transactions, trans)
        #seller.i==2 && println(trans)
    end
end


function res_agg(resdf::AbstractDataFrame, p::MarketParams; kwargs...)
    stat_cols = [:transactions, :price, :price_v, :gain_s, :gain_b, :gain_tot,
                 :double_ended, :property_visits, :step, :step_min, :step_max]

    ress = [
        :TBB => resdf[resdf.tbb .& (.!resdf.allow_de),:],
        :nDE => resdf[(.!resdf.tbb) .& (.!resdf.allow_de),:],
    ]

    de_df = resdf[(.!resdf.tbb) .& resdf.allow_de,:]
    de_regimes = unique(de_df.de_price_premium)
    for de_regime in de_regimes
        label = Symbol(string("DE_",replace(string(de_regime),'.'=>'_')))
        push!(ress, label => de_df[de_df.de_price_premium .== de_regime,:])
    end

    rs = DataFrame()
    for (label, res) in ress
        r = DataFrame(n_sims=nrow(res), regime=label; kwargs...)
        for ff in fieldnames(typeof(p))
            r[!,ff] = [getfield(p,ff)]
        end
        for col in stat_cols
            r[!,col] = [mean(res[!,col])]
        end
        for col in stat_cols
            r[!,Symbol(string(col,"_std"))] = [std(res[!,col])]
        end
        append!(rs,r)
    end
    rs
end

function printsimresults(res)
    r_tbb_nd = res[res.tbb .& (.!res.allow_de),:]
    r_nbb_de = res[(.!res.tbb) .& res.allow_de .& res.de_price_premium==0.0,:]
    r_nbb_nd = res[(.!res.tbb) .& (.!res.allow_de),:]
    stat_cols = [:transactions, :price, :price_v, :gain_s, :gain_b, :gain_tot,
                 :double_ended, :property_visits, :step, :step_min, :step_max]
    stat_list = [:mean, :min, :q25, :median, :q75, :max, :std]

    d_nbb_de=describe(r_nbb_de[!,stat_cols], stat_list... )
    d_nbb_nd=describe(r_nbb_nd[!,stat_cols], stat_list... )
    d_tbb_nd=describe(r_tbb_nd[!,stat_cols], stat_list... )

    println()
    println("TBB & no doubleending");println(d_tbb_nd)
    println("no TBB & doubleending 0.0");println(d_nbb_de)
    println("no TBB & no doubleending");println(d_nbb_nd)

    @assert d_nbb_de.variable == d_nbb_nd.variable == d_tbb_nd.variable
    d_tot = DataFrame(param=d_nbb_de.variable, nbb_de=d_nbb_de.mean,
                        nbb_ndd=d_nbb_nd.mean, TBB_nd=d_tbb_nd.mean)
    println("Total:")
    println(d_tot)
    d_tot
end


function runsims(p::MarketParams;nm=30, nN=30)
    simres = DataFrame(m_id=Int[],N=Int[],tbb=Bool[],
                    allow_de=Bool[], de_price_premium=Union{Float64,Missing}[],
                    nA=Int[],nH=Int[],nB=Int[],transactions=Int[],
                    profit_sa=Float64[],profit_ba=Float64[],
                    price=Float64[],price_v=Float64[],
                    gain_s=Float64[],gain_b=Float64[],gain_tot=Float64[],
                    double_ended=Float64[],property_visits=Float64[],
                    step=Float64[],step_min=Float64[],step_max=Float64[])
    for mm in 1:nm
        m_base = Market(mm,p)
        for (double_ending_price_premium, tbb) in [(0.2,false), (0.1,false), (0.0,false), (nothing,false), (nothing, true)]
            for N in 1:nN
                market = deepcopy(m_base)
                Random.seed!(100_0000+mm);
                res = simulate!(market,steps=60,tbb=tbb,double_ending_price_premium=double_ending_price_premium)
                r  = Dict{Symbol,Union{Int,Float64,Bool,Missing}}(
                            :m_id=>mm,
                            :N=>N,
                            :tbb=>tbb,
                            :allow_de=>double_ending_price_premium != nothing,
                            :de_price_premium => something(double_ending_price_premium, missing),
                            :nA=>length(market.agents),
                            :nH=>length(market.homeowners),
                            :nB=>length(market.buyers),
                            :transactions=>nrow(res),
                            :profit_sa=> nrow(res)==0 ? 0 : mean((res.prov_sa .* res.price) .- (res.cost_sa .* res.seen_s)),
                            :profit_ba=> nrow(res)==0 ? 0 : mean((res.prov_ba .* res.price) .- (res.cost_ba .* res.seen_b)),
                            :price=> nrow(res)==0 ? 0 : mean(res.price),
                            :price_v=> nrow(res)==0 ? 0 : mean(res.price_v),
                            :gain_s=> nrow(res)==0 ? 0 : mean(res.price .- res.price_r),
                            :gain_b=> nrow(res)==0 ? 0 : mean(res.price_v .- res.price),
                            :gain_tot=> nrow(res)==0 ? 0 : mean( res.price_v .- res.price_r ),
                            :double_ended=> nrow(res)==0 ? 0 : mean(res.double_ended),
                            :property_visits=> nrow(res)==0 ? 0 : mean(res.seen_s),
                            :step=> nrow(res)==0 ? 0 : mean(res.step),
                            :step_min=> nrow(res)==0 ? 0 : minimum(res.step),
                            :step_max=> nrow(res)==0 ? 0 : maximum(res.step),
                            )
                push!(simres, r)
            end
        end
    end
    simres
end
