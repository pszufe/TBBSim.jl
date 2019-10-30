@with_kw struct Agent #indexed by k, k=1..nA
    k::Int # index identifier k
    ds = 0.030 # commision for closing a sale when representing a homewoner
    db = 0.020 # commision for closing a sale when representing a buyer
    cb = 0.025 # information cost for buyer
    cs = 0.050 # information cost for seller
end
Agent(k::Int) = Agent(k=k)
@with_kw struct Homeowner  #indexed by i, i=1..nH
    i::Int  # index identfier i
    r::Float64 # reservation price for her property
    ak::Int #representing agent id
    bids = Dict{Int,Float64}()
    seen_by = Set{Int}()
    bid_history = Tuple{Int,Float64}[]
end
Homeowner(i::Int,r::Float64,a::Agent) = Homeowner(i=i,r=r,ak=a.k)



@with_kw struct Buyer   #indexed by j, j=1..nB
    j::Int #index identfier j
    v::Vector{Float64} # her utility for each property i..nH
    ak::Int #representing agent id
    seen_homes = Set{Int}()
    bids = Dict{Int,Float64}()
end
Buyer(j::Int,v::Vector{Float64},a::Agent) =Buyer(j=j,v=v,ak=a.k)

@with_kw struct MarketParams
    nH=100 # number of homeowners
    nB=140 # number of buyers
    nA=10  # number of agents
    home_ln_avg=6.5  # house value (reserved price) for log-normal distribution
    home_ln_std=0.5      # house value std for log-normal distribution
    buyer_value_p=1.1    # value seen by the buyer as a share of house value
    buyer_value_std=0.25 # value seen by the buyer - std
end

@with_kw struct Market
    seed::Int64
    p = MarketParams()
    agents = Agent[]
    homeowners = Homeowner[]
    buyers = Buyer[]
    double_ended_home_buyer = Dict{Int,Int}()
    available_homes = Set{Int}()
    available_buyers = Set{Int}()
    transactions = DataFrame(step=Int[],i=Int[],j=Int[],k_s=Int[],k_b=Int[],
                            allow_de=Bool[],
                            de_price_premium=Union{Float64,Missing}[],
                            seen_s=Int[],seen_b=Int[],
                            cost_sa=Float64[],cost_ba=Float64[],
                            prov_sa=Float64[],prov_ba=Float64[],
                            price_r=Float64[],price_v=Float64[],
                            double_ended=Bool[],price=Float64[])
end



Market(seed::Int64, p::MarketParams) = begin
    market = Market(seed=seed,p=p,agents=Agent.(1:p.nA),available_homes=Set(1:p.nH),available_buyers=Set(1:p.nB))
    house_value_distr = LogNormal(p.home_ln_avg,p.home_ln_std)
    Random.seed!(seed)
    for i=1:p.nH
        push!(market.homeowners, Homeowner(i, round(rand(house_value_distr)),
                                            rand(market.agents)) )
    end

    Random.seed!(10_000+seed)
    as = rand(market.agents,p.nB)
    Random.seed!(20_000+seed)
    for j=1:p.nB
        push!(market.buyers,
                Buyer(j,
                    [round(h.r*p.buyer_value_p+randn()*h.r*p.buyer_value_std)
                    for h in market.homeowners ], as[j]  ))
    end
    market
end
