abstract type AbstractConfig end

Base.@kwdef struct RationalConfig <: AbstractConfig
    top_level_post::Any
    n_agents::Int
end
