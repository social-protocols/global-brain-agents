using Agents

include("../src/discussion-tree.jl")

Base.@kwdef mutable struct SimpleAgent <: Agents.AbstractAgent
    id::Int
    belief::Float64
    observations::Vector{Bool}
    memory::Union{DiscussionTree, Nothing}
end


