# TODO: Confusing that this returns a tuple -> find better structure for API
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
        secret_key, llm, messages;
        tools = [create_persona],
        tool_choice = Dict(
            "type" => "function",
            "function" => Dict("name" => "create_persona"),
        ),
    )

    created_persona_json =
        r.response[:choices][begin][:message][:tool_calls][begin][:function][:arguments]
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

function get_response_from_gpt(
    abm::Agents.ABM,
    agent::BrainAgent,
    messages::Vector{Dict{String, String}},
    nchars_response::Int,
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

            Age: $(agent.age)
            Occupation: $(agent.job)
            Gender: $(agent.gender)
            Character: $(agent.traits)

            Now imagine that you are $(agent.name).
            In no more than $nchars_response characters, please respond as $(agent.name) to the preceding discussion thread. Please respond only with what $(agent.name) would say (in the first person, as if you were $(agent.name)). If you spoke before in the thread, please don't repeat yourself and continue the conversation.
        """
    )
    r = OpenAI.create_chat(
        abm.secret_key, abm.llm,
        [intro_message; messages; task_message],
    )
    # TODO: more sophisticated response extraction
    return r.response[:choices][begin][:message][:content]
end


function get_vote_from_gpt(
    abm::Agents.ABM,
    agent::BrainAgent,
    post::Post,
    note::Union{Post, Nothing},
)::Int
    vote_function = Dict(
        "type" => "function",
        "function" => Dict(
            "name" => "vote",
            "description" => "Vote with an upvote or downvote on a post or ignore it.",
            "parameters" => Dict(
                "type" => "object",
                "properties" => Dict(
                    "vote" => Dict(
                        "type" => "number",
                        "enum" => [-1, 0, 1],
                        "description" => "-1 for downvote, 0 for ignoring, 1 for upvote",
                    ),
                ),
            ),
            "required" => ["vote"]
        )
    )

    messages = Dict{String, String}[]
    post_message = Dict(
        "role" => "user",
        "name" => abm[post.author_id].name,
        "content" => post.content
    )
    push!(messages, post_message)

    if !isnothing(note)
        note_message = Dict(
            "role" => "user",
            "name" => abm[note.author_id].name,
            "content" => note.content
        )
        push!(messages, note_message)
    end

    tool_message = Dict(
        "role" => "system",
        "name" => "Instructor",
        "content" => """
            Imagine you are $(agent.name), a user of a social media platform.
            You have the following persona:

            $(agent.traits)

            As $(agent.name), please provide a vote based on your opinion on the content of the first message from this thread.
        """
    )
    push!(messages, tool_message)

    r = OpenAI.create_chat(
        abm.secret_key, abm.llm, messages;
        tools = [vote_function],
        tool_choice = Dict(
            "type" => "function",
            "function" => Dict(
                "name" => "vote",
            ),
        ),
    )
    vote_json = r.response[:choices][begin][:message][:tool_calls][begin][:function][:arguments]
    vote_dict = JSON.parse(vote_json)
    vote = vote_dict["vote"]

    return vote
end
