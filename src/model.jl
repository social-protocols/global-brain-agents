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


function get_response(
    abm::ABM,
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
    r = create_chat(
        abm.secret_key,
        abm.llm,
        [intro_message; messages; task_message],
    )
    return r.response[:choices][begin][:message][:content]
end


function get_vote(
    abm::ABM,
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

    r = create_chat(
        abm.secret_key,
        abm.llm,
        messages;
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

    try
        @assert vote in [-1, 0, 1]
        return vote
    catch
        @error "Invalid vote: $vote"
        return 0
    end
end


function vote!(abm::ABM, agent::BrainAgent, post::Post)::Tuple{ABM, BrainAgent}
    current_vote = findlast(
        v -> v.post_id == post.id && v.user_id == agent.id,
        abm.votes
    )
    if !isnothing(current_vote)
        return abm, agent
    end
    vote = get_vote(abm, agent, post, nothing)
    if vote == 0
        return abm, agent
    end
    vote = Vote(
        post_id = post.id,
        user_id = agent.id,
        upvote = vote == 1 ? true : false,
        timestamp = abm.step
    )
    push!(abm.votes, vote)
    return abm, agent
end


# TODO: agents only reply to posts of other agents
function reply!(
    abm::ABM,
    agent::BrainAgent,
    post_id::Int,
)::Tuple{ABM, BrainAgent}
    parent_thread = get_parent_thread(abm, post_id)
    context_messages = Dict{String, String}[
        Dict(
            "role" => p.author_id == agent.id ? "system" : "user",
            "name" => abm[p.author_id].name,
            "content" => p.content
        )
        for p in parent_thread
    ]
    # TODO: return as message, then unpack here
    content = get_response(abm, agent, context_messages, 280)
    reply = Post(
        id = length(abm.posts) + 1,
        parent_id = post_id,
        content = content,
        author_id = agent.id,
        timestamp = abm.step
    )
    push!(abm.posts, reply)
    return abm, agent
end


function get_parent_thread(abm::ABM, post_id::Int)::Vector{Post}
    post = abm.posts[post_id]
    if isnothing(post.parent_id)
        return [post]
    else
        return [get_parent_thread(abm, post.parent_id); post]
    end
end


function agent_step!(agent::BrainAgent, abm::ABM)::Tuple{BrainAgent, ABM}
    vote!(abm, agent, abm.posts[rand(1:length(abm.posts))])
    if rand() < 0.8 # hard-coded reply probability, TODO: more sophisticated
        reply!(abm, agent, rand(1:length(abm.posts)))
    end
    return agent, abm
end


function model_step!(abm::ABM)::ABM
    abm.step += 1
    return abm
end
