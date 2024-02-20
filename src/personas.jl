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

    @showprogress for _ in 1:n
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
        push!(personas, persona)
        push!(context_messages, new_context_message)
    end

    @info "Created $(n) personas."
    return personas
end
