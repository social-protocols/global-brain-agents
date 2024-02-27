PRIOR_BELIEF = 0.5


Base.@kwdef mutable struct RationalAgent <: Agents.AbstractAgent
    id::Int
    belief::Float64
    weight::Float64
    observation::Bool
    memory::Union{DiscussionTree, Nothing}
end


Base.@kwdef struct RationalPost <: AbstractPost
    id::Int
    parent_id::Union{Int, Nothing}
    content::Any # TODO
    author_id::Int
    timestamp::Int
end


function bayesian_avg(
    prior::Tuple{Float64, Float64},
    new_observed_mean::Float64,
)::Tuple{Float64, Float64}
    return (
        (prior[1] * prior[2] + new_observed_mean) / (prior[2] + 1),
        prior[2] + 1,
    )
end

struct RationalTally
    count::Int
    sample_size::Int
end


function bayesian_avg(agent::RationalAgent, new_data::RationalTally)::Tuple{Float64, Float64}
    new_weight = agent.weight + new_data.sample_size
    return (
        (agent.belief * agent.weight + new_data.count) / new_weight,
        new_weight
    )
end



function update_belief!(
    agent::RationalAgent,
    observed_tally::RationalTally,
)::RationalAgent
    agent.belief, agent.weight = bayesian_avg(agent, observed_tally)
    return agent
end


