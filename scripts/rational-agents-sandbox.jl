if isinteractive()
    include(joinpath("src", "GlobalBrainAgents.jl"))
else
    include(joinpath("..", "src", "GlobalBrainAgents.jl"))
end

using Main.GlobalBrainAgents

cfg = RationalConfig(
    top_level_post = "Hello, World!",
    n_agents = 10
)

abm = create_agent_based_model(cfg)

println(abm)

println(abm.posts[begin])

agent_step!(abm[1], abm)
