function create_personas(
    n::Int,
    p_asshole::Float64,
    secret_key::String,
    llm::String,
)::Vector{Dict{String, Any}}
    context_messages = [
        Dict(
            "role" => "system",
            "content" => """
                Personas should be as diverse as possible in terms of all of their attributes.
            """
        ),
        Dict(
            "role" => "system",
            "content" => """
                The personas' jobs should reflect different levels of eductation.
            """
        ),
        Dict(
            "role" => "system",
            "content" => """
                Personas' ages should cover a wide range.
            """
        ),
        Dict(
            "role" => "system",
            "content" => """
                Personas' names should should not all be Anglo-American.
            """
        ),
    ]

    personas = Dict{String, Any}[]

    @info "Generating personas..."

    ProgressMeter.@showprogress for _ in 1:n
        task_message = if rand() < p_asshole
            Dict(
                "role" => "user",
                "content" => "Please create a persona."
            )
        else
            Dict(
                "role" => "user",
                "content" => "Please create a persona. Make sure he or she is a real asshole."
            )
        end
        messages = [context_messages; task_message]
        persona, new_context_message = get_persona_from_gpt(messages, secret_key, llm)
        if !is_valid_persona(persona)
            @warn "Invalid persona: $persona"
            continue
        end
        push!(personas, persona)
        push!(context_messages, new_context_message)
    end

    @info "Created $(length(personas)) personas."
    return personas
end

function is_valid_persona(persona::Dict{String, Any})::Bool
    required_keys = ["name", "age", "gender", "job", "traits"]
    actual_keys = collect(keys(persona))
    return (
        isempty(setdiff(required_keys, actual_keys)) &&
        isempty(setdiff(required_keys, actual_keys))
    )
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


function get_gpt_agents(n::Int, db::SQLite.DB)::Vector{GPTAgent}
    query = """
        SELECT *
        FROM personas
        ORDER BY RANDOM()
        LIMIT $n
    """
    personas = DBInterface.execute(db, query)
    agents =  [
        GPTAgent(
            id = persona[:id],
            name = persona[:name],
            age = persona[:age],
            gender = persona[:gender],
            job = persona[:job],
            traits = persona[:traits],
            memory = nothing,
        )
        for persona in personas
    ]
    if length(agents) < n
        @warn "Only found $(length(agents)) personas in the database."
    end
    return agents
end

