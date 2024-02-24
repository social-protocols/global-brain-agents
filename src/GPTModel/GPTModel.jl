module GPTModel

using Agents
using Random
using SQLite
using OpenAI
using JSON
using ProgressMeter
using GlobalBrain
using ..GlobalBrainAgents

include("model.jl")
include("openai-api.jl")
include("personas.jl")
include("simulation.jl")


export GPTAgent

export vote!
export reply!

export agent_step!
export model_step!

export create_agent_based_model
export populate!
export run_simulation!

export create_personas
export insert_personas!
export get_gpt_agents

export get_vote_from_gpt
export get_reply_from_gpt
export get_persona_from_gpt

export create_personas
export get_gpt_agents

end
