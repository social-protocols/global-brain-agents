function create_agent_based_model(top_level_post::String, secret_key::String, llm::String)::Agents.ABM
    return ABM(
        BrainAgent;
        properties = Dict(
            :secret_key => secret_key,
            :llm => llm,
            :posts => Post[
                Post(
                    id = 1,
                    parent_id = nothing,
                    content = top_level_post,
                    author_id = 1,
                    timestamp = 0,
                )
            ],
            :votes => Vote[Vote(1, 1, true, 0)], # OP upvote
            :step => 0,
        ),
    )
end


function populate!(abm::Agents.ABM, n_agents::Int, db::SQLite.DB)::Agents.ABM
    agents = get_agents(n_agents, db)
    for a in agents
        add_agent!(a, abm)
    end
    return abm
end


function run_simulation!(
    abm::Agents.ABM,
    n_steps::Int,
    db::SQLite.DB;
    showprogress::Bool = true
)::Agents.ABM
    @info "Running model..."
    run!(abm, agent_step!, model_step!, n_steps; showprogress = showprogress, agents_first = false)
    @info "Model run successful!"

    @info "Saving data to database..."
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

    for p in abm.posts
        DBInterface.execute(db, """
            INSERT INTO posts (id, parent_id, content, author_id, timestamp)
            VALUES (?, ?, ?, ?, ?)
        """, (p.id, p.parent_id, p.content, p.author_id, p.timestamp))
    end
    for v in abm.votes
        DBInterface.execute(db, """
            INSERT INTO votes (post_id, user_id, upvote, timestamp)
            VALUES (?, ?, ?, ?)
        """, (v.post_id, v.user_id, v.upvote, v.timestamp))
    end

    return abm
end




