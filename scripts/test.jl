include("../src/GlobalBrainAgents.jl")

using Main.GlobalBrainAgents

OPENAI_API_KEY = get(ENV, "OPENAI_API_KEY", "")
LLM = "gpt-3.5-turbo"
DATABASE_PATH = get(ENV, "DATABASE_PATH", joinpath("data", "results.db"))
TOP_LEVEL_POST = "How would you handle AI governance in the near future? What are the most important policies to implement?"

# println("A database already exists at the specified path. Do you want to delete it? (y/n)")
# delete_db_spec = readline()
# if delete_db_spec == "y" && isfile(DATABASE_PATH)
#     @warn "Deleting database at $DATABASE_PATH."
#     rm(DATABASE_PATH)
# else
#     error("Aborting to avoid data loss. Please specify a different path.")
# end

# db = create_db(DATABASE_PATH)
# personas = create_personas(5, 0.5, OPENAI_API_KEY, LLM)
# insert_personas!(db, personas)
db = get_db(DATABASE_PATH)
abm = create_agent_based_model(TOP_LEVEL_POST, OPENAI_API_KEY, LLM)
populate!(abm, 5, db)
run_simulation!(abm, 10, db)
