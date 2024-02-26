PRIOR_BELIEF = 0.5

Base.@kwdef mutable struct RationalAgent <: Agents.AbstractAgent
    id::Int
    belief::Float64
    observations::Vector{Bool}
    memory::Union{DiscussionTree, Nothing}
end


Base.@kwdef struct RationalPost <: AbstractPost
    id::Int
    parent_id::Union{Int, Nothing}
    content::Any # TODO
    author_id::Int
    timestamp::Int
end


function update_belief!(agent::RationalAgent, observed_mean::Float64)::RationalAgent
    if isempty(agent.observations)
        return agent
    end
    agent.belief = sum(agent.observations) / length(agent.observations)
    return agent
end

