module GlobalBrainAgents

using Agents
using Random
using OpenAI
using JSON
using SQLite
using DataFrames
using ProgressMeter
using GlobalBrain


include("types.jl")
include("discussion-tree.jl")
include("config.jl")
include("db.jl")
include("global-brain-api.jl")

include("personas.jl")
include("gpt-model.jl")
include("openai-api.jl")

include("rational-model.jl")

include("base-model.jl")
include("simulation.jl")


export AbstractPost
export Vote

export DiscussionTree
export nodes
export descendents
export add_node!
export get_leaves



export vote!
export reply!

export agent_step!
export model_step!

export create_agent_based_model

export populate!
export run_simulation!



export create_db
export get_db
export construct_inmemory_tree
export to_tallies_tree_iterable
export get_detailed_tally





export GPTAgent
export GPTPost

export get_vote_from_gpt
export get_reply_from_gpt
export get_persona_from_gpt
export create_personas
export insert_personas!



export RationalAgent
export RationalPost
export RationalConfig



end
