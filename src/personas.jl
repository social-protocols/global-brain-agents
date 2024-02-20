# --- The public interface ---

function create_agents(
    n::Int,
    p_asshole::Float64,
    db::Union{SQLite.DB, Nothing},
    secret_key::String,
    llm::String,
)::Vector{BrainAgent}
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

    for _ in 1:n
        messages = [context_messages; get_persona_creation_task_message(p_asshole)]
        persona, new_context_message = get_persona_from_gpt(messages, secret_key, llm)
        if !is_valid(persona)
            @warn "Invalid persona: $persona"
            continue
        end
        push!(personas, persona)
        push!(context_messages, new_context_message)
    end

    enumerated_personas = collect(enumerate(personas))

    if !isnothing(db)
        insert_personas(db, enumerated_personas)
    end

    return map(create_agent_from_persona, enumerated_personas)
end

function insert_personas(
    db::SQLite.DB,
    indexed_personas::Vector{Tuple{Int, Dict{String, Any}}}
)::Nothing
    for (idx, persona) in indexed_personas
        DBInterface.execute(
            db,
            """
                INSERT INTO personas (id, name, age, gender, job, traits)
                VALUES (?, ?, ?, ?, ?, ?)
            """,
            (
                idx,
                persona["name"],
                persona["age"],
                persona["gender"],
                persona["job"],
                persona["traits"]
            ),
        )
    end
    @info "Persisted $(length(indexed_personas)) personas."
end


# --- Private helper functions ---


function get_persona_from_gpt(
    messages::Vector{Dict{String, String}},
    secret_key::String,
    llm::String,
)::Tuple{Dict, Dict}
    create_persona = Dict(
        "type" => "function",
        "function" => Dict(
            "name" => "create_persona",
            "description" => "Create a persona with given attributes.",
            "parameters" => Dict(
                "type" => "object",
                "properties" => Dict(
                    "name" => Dict(
                        "type" => "string",
                        "description" => "The persona's first name",
                    ),
                    "age" => Dict(
                        "type" => "number",
                        "enum" => collect(0:100),
                        "description" => "A number between 0 and 100",
                    ),
                    "gender" => Dict(
                        "type" => "string",
                        "enum" => ["m", "f", "d"],
                        "description" => "m for male, f for female, d for diverse",
                    ),
                    "job" => Dict(
                        "type" => "string",
                        "description" => "The persona's occupation",
                    ),
                    "traits" => Dict(
                        "type" => "string",
                        "description" => "A description of the persona's character and how they interact with others in 100 to 200 characters",
                    ),
                ),
            ),
            "required" => ["name", "age", "gender", "job", "traits"],
        )
    )

    r = OpenAI.create_chat(
        secret_key,
        llm,
        messages;
        tools = [create_persona],
        tool_choice = Dict(
            "type" => "function",
            "function" => Dict(
                "name" => "create_persona",
            ),
        ),
    )
    tool_call = r.response[:choices][begin][:message][:tool_calls][begin]
    created_persona_json = tool_call[:function][:arguments]
    new_context_message = Dict(
        "role" => "system",
        "content" => """
            The following agent already exists:
            $created_persona_json
            Make sure to consider the diversity of the personas and don't create this or a similar agent again.
        """,
    )
    persona = JSON.parse(created_persona_json)
    return persona, new_context_message
end


function get_persona_creation_task_message(p_asshole::Float64)::Dict
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
    return task_message
end


function is_valid(persona::Dict)::Bool
    return isempty(setdiff(keys(persona), Set(["name", "age", "gender", "job", "traits"])))
end


function create_agent_from_persona(
    indexed_persona::Tuple{Int, Dict{String, Any}},
)::BrainAgent
    idx, persona = indexed_persona
    return BrainAgent(
        idx,
        persona["name"],
        persona["age"],
        persona["gender"],
        persona["job"],
        persona["traits"],
    )
end

