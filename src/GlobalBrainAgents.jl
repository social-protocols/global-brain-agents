module GlobalBrainAgents

using Agents
using Random
using OpenAI
using JSON

include("model.jl")
include("db.jl")
include("personas.jl")

export create_db
export create_agents

end
