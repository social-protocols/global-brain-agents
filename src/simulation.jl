function initialize_simulation()
    # TODO
end

function run_simulation!(
    abm::Agents.ABM,
    n_steps::Int,
    db::SQLite.DB;
    showprogress::Bool = true,
)::Agents.ABM
    @info "Running model..."
    Agents.run!(
        abm, agent_step!, model_step!, n_steps;
        showprogress = showprogress, agents_first = false
    )
    @info "Model run successful!"

    # TODO: move this to database layer, i.e., hide in a function
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
