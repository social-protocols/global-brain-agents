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

function get_reply_from_gpt(
    abm::Agents.ABM,
    agent::GPTAgent,
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
    agent::GPTAgent,
    post::Post,
    note::Union{Post, Nothing} = nothing,
)::Any # TODO: return type
    vote_function = Dict(
        "type" => "function",
        "function" => Dict(
            "name" => "vote",
            "description" => "Vote with an upvote or downvote on a post or ignore it.",
            "parameters" => Dict(
                "type" => "object",
                "properties" => Dict(
                    "explanation" => Dict(
                        "type" => "string",
                        "description" => "Explanation why the decision was taken to vote on a certain way and if the context influenced you in that decision",
                    ),
                    "vote" => Dict(
                        "type" => "number",
                        "enum" => [-1, 0, 1],
                        "description" => "-1 for downvote, 0 for ignoring, 1 for upvote",
                    ),
                ),
            ),
            "required" => ["explanation", "vote"]
        )
    )
    messages = Dict{String, String}[]

    intro_message = Dict(
        "role" => "system",
        "name" => "Instructor",
        "content" => """
            You are using a social media platform, like Twitter.
            You read the following discussion thread.
        """
    )
    push!(messages, intro_message)

    parent_thread = get_parent_thread(abm, post.id)
    for parent_post in parent_thread
        parent_post_message = Dict(
            "role" => "user",
            "name" => abm[parent_post.author_id].name,
            "content" => parent_post.content
        )
        push!(messages, parent_post_message)
    end


    post_message = Dict(
        "role" => "user",
        "name" => abm[post.author_id].name,
        "content" => post.content
    )
    push!(messages, post_message)

    note_task_primer_content = if !isnothing(note)
        """
            You will also view a reply to that post, for extra context. When you vote, you take into account the extra context from the reply. 
            Make your decision about the post itself, the reply is simply for extra context. 
            Do not vote on the reply.
        """
    else
        ""
    end

    reply_example_1, reply_example_2 = if !isnothing(note)
        (
            """```reply```:  The horizon appears flat to the naked eye, and if the Earth were truly a sphere, we would be able to detect the curvature.""",
            """```reply```: That's false because you can circumnavigate the globe""",
        )
    else
        ("", "")
    end

    note_examples = if !isnothing(note)
        """
            Example 1:
               ```post```: The earth is flat  
                $reply_example_1
                ```action to the post```: Upvote the post
            Example 2
                ```post```: The earth is flat
                $reply_example_2
                ```action to the post```: Downvote the post
        """
    else
        ""
    end

    task_message = if !isnothing(note)
        """
            Following is the post and a reply to that post. Please vote on the post providing your reasoning behind it.
        """
    else
        ""
    end

    persona_task_primer = Dict(
        "role" => "system",
        "name" => "Instructor",
        "content" => """
            You are the following persona:

            ```
            name: $(agent.name)
            age: $(agent.age)
            gender: $(agent.gender)
            job: $(agent.job)
            traits: $(agent.traits)
            ```

            You engage with things that interest you, raise your opinions and vote on things you like.
            You are going to view a post and upvote, downvote or ignore it.

            $note_task_primer_content

            $note_examples

            $task_message
        """
    )
    push!(messages, persona_task_primer)

    post_message = Dict(
        "role" => "user",
        "name" => abm[post.author_id].name,
        "content" => post.content,
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

    r = OpenAI.create_chat(
        abm.secret_key, abm.llm, messages;
        tools = [vote_function],
        tool_choice = Dict(
            "type" => "function",
            "function" => Dict(
                "name" => "vote",
            ),
        ),
        # logprobs = true,
    )
    # vote_json = r.response[:choices][begin][:message][:tool_calls][begin][:function][:arguments]
    # vote_dict = JSON.parse(vote_json)
    # vote = vote_dict["vote"]

    return r
end
