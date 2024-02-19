@agent BrainAgent NoSpaceAgent begin
    name::String
    age::Int
    gender::String
    job::String
    traits::String
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


vote_function =
    Dict(
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
            In no more than $nchars_response characters, please respond as $(agent.name) to the preceding discussion thread. Please respond only with what $(agent.name) would say (in the first person, as if you were $(agent.name)). If you spoke before in the thread, please don't repeat yourself and continue the conversation.
        """
    )
    r = create_chat(
        secret_key,
        model,
        [intro_message; messages; task_message],
    )
    return r.response[:choices][begin][:message][:content]
end

function get_vote(
    model::ABM,
    agent::BrainAgent,
    post::Post,
    note::Union{Post, Nothing} = nothing,
    llm::String = LLM,
    secret_key::String = SECRET_KEY,
    tools::Vector{Dict{String, Any}} = TOOLS,
)::Int
    messages = Dict{String, String}[]
    post_message = Dict(
        "role" => "user",
        "name" => model[post.author_id].name,
        "content" => post.content
    )
    push!(messages, post_message)
    if !isnothing(note)
        note_message = Dict(
            "role" => "user",
            "name" => model[note.author_id].name,
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

            $(agent.persona)

            As $(agent.name), please provide a vote based on your opinion on the content of the first message from this thread.
        """
    )
    push!(messages, tool_message)
    r = create_chat(
        secret_key,
        llm,
        messages;
        tools = tools,
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
    try
        @assert vote in [-1, 0, 1]
        return vote
    catch
        @error "Invalid vote: $vote"
        return 0
    end
end

function vote!(model::ABM, agent::BrainAgent, post::Post)::Tuple{ABM, BrainAgent}
    current_vote = findlast(
        v -> v.post_id == post.id && v.user_id == agent.id,
        model.votes
    )
    if !isnothing(current_vote)
        @info "Agent $(agent.name) already voted on post $(post.id)"
        return model, agent
    end
    vote = get_vote(model, agent, post)
    if vote == 0
        return model, agent
    end
    vote = Vote(
        post_id = post.id,
        user_id = agent.id,
        upvote = vote == 1 ? true : false,
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
    vote!(model, agent, model.posts[rand(1:length(model.posts))])
    if rand() < 0.8 # hard-coded reply probability, TODO: more sophisticated
        reply!(model, agent, rand(1:length(model.posts)))
    end
    return agent, model
end

function model_step!(model::ABM)::ABM
    model.step += 1
    return model
end
