# --- PLAN:
# --- - use global reply:vote ratio as parameter to decide whether to reply or vote
# --- - create different personas for agents with chatgpt
# --- - let gpt up or downvote
# --- - let gpt reply
# --- - use GlobalBrain.jl to score posts after every model step
# --- - use Thompson sampling to decide which post to display as a note

using Agents
using DataFrames
using Random
using Distributions
using OpenAI
using SQLite

# --- Constants

SECRET_KEY = get(ENV, "OPENAI_API_KEY", "")
LLM = "gpt-3.5-turbo"
TOP_LEVEL_POST = "Using the metric system reduces the cognitive load of converting units."
DATABASE_PATH = get(ENV, "DATABASE_PATH", "data/results.db")
NCHARS_RESPONSE = 280

# --- Define model

@agent BrainAgent NoSpaceAgent begin
    name::String
    persona::String
    vote_probability::Float64
    upvote_probability::Float64
end

Base.@kwdef struct Post
    id::Int
    parent_id::Union{Int, Nothing}
    content::String
    author_id::Int
    timestamp::Int # model step
end

Base.@kwdef struct Vote
    post_id::Int
    user_id::Int
    upvote::Bool
    timestamp::Int # model step
end

function get_response(
    agent::BrainAgent,
    messages::Vector{Dict{String, String}},
    secret_key::String = SECRET_KEY,
    model::String = LLM,
    nchars_response::Int = NCHARS_RESPONSE,
)::String
    intro_message = Dict(
        "role" => "user",
        "name" => "Instructor",
        "content" => """
            Following is a discussion thread that you participate in as $(agent.name).
        """
    )
    task_message = Dict(
        "role" => "user",
        "name" => "Instructor",
        "content" => """
            $(agent.name) has the following persona.

            $(agent.persona)

            Now imagine that you are $(agent.name).
            In no more than $nchars_response characters, please respond as $(agent.name) to the preceding discussion thread. Please respond only with what $(agent.name) would say (in the first person, as if you were $(agent.name)).
        """

    )
    r = create_chat(
        secret_key,
        model,
        [intro_message; messages; task_message],
    )
    return r.response[:choices][begin][:message][:content]
end

# TODO: don't allow multiple votes on same post
function vote!(model::ABM, agent::BrainAgent, post::Post)::Tuple{ABM, BrainAgent}
    agent_dist = Bernoulli(agent.upvote_probability)
    vote = Vote(
        post_id = post.id,
        user_id = agent.id,
        upvote = rand(agent_dist),
        timestamp = model.step
    )
    push!(model.votes, vote)
    return model, agent
end

# TODO: agents only reply to posts of other agents
function reply!(
    model::ABM,
    agent::BrainAgent,
    post_id::Int,
)::Tuple{ABM, BrainAgent}
    parent_thread = get_parent_thread(post_id, model)
    context_messages = Dict{String, String}[
        Dict(
            "role" => p.author_id == agent.id ? "system" : "user",
            "name" => model[p.author_id].name,
            "content" => p.content
        )
        for p in parent_thread
    ]
    # TODO: return as message, then unpack here
    content = get_response(agent, context_messages)
    reply = Post(
        id = length(model.posts) + 1,
        parent_id = post_id,
        content = content,
        author_id = agent.id,
        timestamp = model.step
    )
    push!(model.posts, reply)
    return model, agent
end

function get_parent_thread(post_id::Int, model::ABM)::Vector{Post}
    post = model.posts[post_id]
    if isnothing(post.parent_id)
        return [post]
    else
        return [get_parent_thread(post.parent_id, model); post]
    end
end

function agent_step!(agent::BrainAgent, model::ABM)::Tuple{BrainAgent, ABM}
    if rand() < agent.vote_probability
        vote!(model, agent, model.posts[rand(1:length(model.posts))])
    end
    if rand() < 0.8
        reply!(model, agent, rand(1:length(model.posts)))
    end
    return agent, model
end

function model_step!(model::ABM)::ABM
    model.step += 1
    return model
end

# --- Run model

properties = Dict(
    :posts => Post[
        # initial top-level post by Alice
        Post(
            id = 1,
            parent_id = nothing,
            content = TOP_LEVEL_POST,
            author_id = 1,
            timestamp = 0,
        )
    ],
    :votes => Vote[Vote(1, 1, true, 0)], # Alice's OP upvote
    :step => 0,
)

model = ABM(BrainAgent; properties = properties)

# TODO: create personas with GPT
add_agent!(
    BrainAgent(
        1,
        "Alice",
        "age 37, inquisitive, very confrontational, doesn't shy away from a conflict, smart",
        rand(2)...
    ),
    model
)
add_agent!(
    BrainAgent(
        2,
        "Bob",
        "age 21, shy, introverted, likes to read, doesn't like to argue, smart, likes harmonic interactions",
        rand(2)...
    ),
    model
)
add_agent!(
    BrainAgent(
        3,
        "Charlie",
        "age 41, violent tendencies, insults people on the Internet, very dumb",
        rand(2)...
    ),
    model
)

@info "Running model..."

run!(model, agent_step!, model_step!, 30; showprogress = true, agents_first = false)

@info "Model run successful!"

posts_data = DataFrame(
    Dict(
        fn => [getfield(p, fn) for p in model.posts]
        for fn in fieldnames(Post)
    )
)

votes_data = DataFrame(
    Dict(
        fn => [getfield(v, fn) for v in model.votes]
        for fn in fieldnames(Vote)
    )
)

# --- DB

db = SQLite.DB(DATABASE_PATH)
DBInterface.execute(db, "DROP TABLE IF EXISTS posts")
DBInterface.execute(db, "DROP TABLE IF EXISTS votes")
DBInterface.execute(db, """
    CREATE TABLE IF NOT EXISTS posts (
          id        INTEGER PRIMARY KEY
        , parent_id INTEGER
        , content   TEXT
        , author_id INTEGER NOT NULL
        , timestamp INTEGER NOT NULL
    )
""")
DBInterface.execute(db, """
    CREATE TABLE IF NOT EXISTS votes (
          post_id   INTEGER NOT NULL
        , user_id   INTEGER NOT NULL
        , upvote    BOOLEAN NOT NULL
        , timestamp INTEGER NOT NULL
    )
""")
for p in model.posts
    DBInterface.execute(db, """
        INSERT INTO posts (id, parent_id, content, author_id, timestamp)
        VALUES (?, ?, ?, ?, ?)
    """, (p.id, p.parent_id, p.content, p.author_id, p.timestamp))
end
for v in model.votes
    DBInterface.execute(db, """
        INSERT INTO votes (post_id, user_id, upvote, timestamp)
        VALUES (?, ?, ?, ?)
    """, (v.post_id, v.user_id, v.upvote, v.timestamp))
end
