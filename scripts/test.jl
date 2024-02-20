include("../src/GlobalBrainAgents.jl")

using Main.GlobalBrainAgents

OPENAI_API_KEY = get(ENV, "OPENAI_API_KEY", "")
LLM = "gpt-3.5-turbo"
DATABASE_PATH = get(ENV, "DATABASE_PATH", joinpath("data", "results.db"))
TOP_LEVEL_POST = "Social Media is destroying society."

println("A database already exists at the specified path. Do you want to delete it? (y/n)")
delete_db_spec = readline()
if delete_db_spec == "y" && isfile(DATABASE_PATH)
    rm(DATABASE_PATH)
else
    error("Aborting for safety reasons. Please specify a different path.")
end

db = create_db(DATABASE_PATH)

abm = create_agent_based_model(TOP_LEVEL_POST, OPENAI_API_KEY, LLM)

populate!(abm, 3, 0.8, db)

run_simulation!(abm, 10, db)
