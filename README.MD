# TBBSim.jl

This is a repository containig a simulation model accompying the paper:

*Usurping Double-Ending Fraud in Real Estate Transactions via Blockchain Technology*

by Seung Hwan (Mark) Lee, Victoria Lemieux, Atefeh (Atty) Mashatan and Przemyslaw Szufel 

submitted the Journal of Database Management (JDM) 


## Agent Based Simulation for the Double-Ending Related Fraud

The Blockchain based solution for collection of bids from buyers brings transparency to the property market and hence provides new level of market efficiency (reducing the level of fraud, provides a better matching of buyers to sellers and avoid situations of price manipulation).  Currently, in  the property market, there is an information asymmetry between the buyers and sellers versus buying and selling agents. In particular, neither buyer nor the seller know whether their respective agent is acting in their best interest given they do not have easy access to the bids. All the bids are presented to the seller through their agent.   
Double-ending is not necessarily a fraudulent activity. It becomes a fraudulent activity when the agent prioritizes his or her own interests over the client they are representing, For example, 1) the agent may not present ALL the bids to the seller; 2) they may also delay presenting some of the bids; and 3) they may fast track a bid that is in their own interest, but not the seller’s interest. In all of these cases, the seller is the victim. There is a potential buyer who is also a victim because they won’t be able to purchase the house they want due to the actions of the dual agent.  The above-noted problems can occur because of a misalignment of incentives between agents and their clients. For example,  with each new buyer the selling agent is incurring the cost of presenting the property to the potential buyer (includes cost of travelling to the property and presenting to the potential buyer). Note that this "information cost" means that the seller has a strong motivation to limit the number of potential buyers to see the property, even though the seller potentially benefits when more potential buyers have an opportunity to view the property. Similarly, in the case of the buyer and her agent, since the buyer’s agent is paid a commission only when the deal is closed, her incentives are different than the incentives of the house owner she is representing.  The market information asymmetry can lead to a situation where the market ends in an equilibrium that is not optimal for either the buyers or for the sellers.  The information asymmetry can be removed by the introduction of  blockchain-based solution where buyers and sellers have full information (i.e, transparency) about the transaction and offers of all bidders.

In this repository we present a TBB agent based simulation of the property market.

In order to run the simulation please run the following julia commnads:

```julia
using Pkg
Pkg.add(PackageSpec(url="https://github.com/pszufe/TBBSim.jl.git#master"))
```
