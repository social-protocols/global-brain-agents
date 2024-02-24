include("../src/GlobalBrainAgents.jl")
using Main.GlobalBrainAgents
using JSON

OPENAI_API_KEY = get(ENV, "OPENAI_API_KEY", "")
LLM = "gpt-3.5-turbo"
DATABASE_PATH = get(ENV, "DATABASE_PATH", joinpath("data", "results.db"))
TOP_LEVEL_POST = "an earthquake happened in mexico, check out this video"

if isfile(DATABASE_PATH)
    println("A database already exists at the specified path. Do you want to delete it? (y/n)")
    delete_db_spec = readline()
    if delete_db_spec == "y" && isfile(DATABASE_PATH)
        @warn "Deleting database at $DATABASE_PATH."
        rm(DATABASE_PATH)
    else
        error("Aborting to avoid data loss. Please specify a different path.")
    end
end

db = create_db(DATABASE_PATH)
personas = [
    Dict(
        "name" => "Alice",
        "age" => 25,
        "gender" => "w",
        "job" => "engineer",
        "traits" => "curious, open-minded, creative",
    ),
    Dict(
        "name" => "Bob",
        "age" => 30,
        "gender" => "m",
        "job" => "lawyer",
        "traits" => "skeptical, analytical, detail-oriented",
    ),
    Dict(
        "name" => "Charlie",
        "age" => 35,
        "gender" => "m",
        "job" => "doctor",
        "traits" => "empathetic, caring, patient",
    ),
]
insert_personas!(db, personas)
db = get_db(DATABASE_PATH)
abm = create_agent_based_model(TOP_LEVEL_POST, OPENAI_API_KEY, LLM)
populate!(abm, 3, db)

post = GlobalBrainAgents.Post(
    id = 2,
    parent_id = 1,
    content = "wait thats footage from an earthquake from 3 years ago in Indonesia",
    author_id = 1,
    timestamp = 1,
)
note = GlobalBrainAgents.Post(
    id = 3,
    parent_id = 2,
    content = "actually, it's from Mexico, and it's from last week. I'm a journalist and I was there. I can provide more information if you want.",
    author_id = 2,
    timestamp = 2,
)
push!(abm.posts, post)
push!(abm.posts, note)


vote_without_note_raw = get_vote_from_gpt(abm, abm[3], abm.posts[2])
vote_with_note_raw = get_vote_from_gpt(abm, abm[3], abm.posts[2], abm.posts[3])

vote_without_note = JSON.parse(vote_without_note_raw.response[:choices][begin][:message][:tool_calls][begin][:function][:arguments])
vote_with_note = JSON.parse(vote_with_note_raw.response[:choices][begin][:message][:tool_calls][begin][:function][:arguments])

println(vote_without_note)
println(vote_with_note)

