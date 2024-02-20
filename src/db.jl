function create_db(path::String)::SQLite.DB
    db = SQLite.DB(path)
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
    DBInterface.execute(db, """
        CREATE TABLE IF NOT EXISTS personas (
              id     INTEGER PRIMARY KEY
            , name   TEXT
            , age    INTEGER
            , gender TEXT
            , job    TEXT
            , traits TEXT
        )
    """)
    return db
end


function get_db(path::String)::SQLite.DB
    if isfile(path)
        return SQLite.DB(path)
    else
        error("No database exists at path $path.")
    end
end


function insert_personas!(db::SQLite.DB, personas::Vector{Dict{String, Any}},)::Nothing
    query = """
        INSERT INTO personas (name, age, gender, job, traits)
        VALUES (?, ?, ?, ?, ?)
    """
    for persona in personas
        DBInterface.execute(
            db,
            query,
            (
                persona["name"],
                persona["age"],
                persona["gender"],
                persona["job"],
                persona["traits"]
            ),
        )
    end
    @info "Persisted $(length(personas)) personas."
end


function get_agents(n::Int, db::SQLite.DB)::Vector{BrainAgent}
    query = """
        SELECT *
        FROM personas
        ORDER BY RANDOM()
        LIMIT $n
    """
    personas = DBInterface.execute(db, query)
    agents =  [
        BrainAgent(
            persona[:id],
            persona[:name],
            persona[:age],
            persona[:gender],
            persona[:job],
            persona[:traits],
        )
        for persona in personas
    ]
    if length(agents) < n
        @warn "Only found $(length(personas)) personas in the database."
    end
    return agents
end
