Base.@kwdef mutable struct BrainAgent <: Agents.AbstractAgent
    id::Int
    name::String
    age::Int
    gender::String
    job::String
    traits::String
end


Base.@kwdef struct Post
    id::Int
    parent_id::Union{Int, Nothing} # if nothing -> top-level post
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


function vote!(
    abm::Agents.ABM,
    agent::BrainAgent,
    post::Post,
    note::Union{Post, Nothing} = nothing,
)::Tuple{Agents.ABM, BrainAgent}
    current_vote = findlast(
        v -> v.post_id == post.id && v.user_id == agent.id,
        abm.votes
    )
    if !isnothing(current_vote)
        return abm, agent
    end
    vote = get_vote_from_gpt(abm, agent, post, note)
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


function reply!(
    abm::Agents.ABM,
    agent::BrainAgent,
    post_id::Int,
)::Tuple{Agents.ABM, BrainAgent}
    parent_thread = get_parent_thread(abm, post_id)
    context_messages = Dict{String, String}[
        Dict(
            "role" => p.author_id == agent.id ? "system" : "user",
            "name" => abm[p.author_id].name,
            "content" => p.content
        )
        for p in parent_thread
    ]
    content = get_response_from_gpt(abm, agent, context_messages, 280)
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


function get_parent_thread(abm::Agents.ABM, post_id::Int)::Vector{Post}
    post = abm.posts[post_id]
    if isnothing(post.parent_id)
        return [post]
    else
        return [get_parent_thread(abm, post.parent_id); post]
    end
end


function agent_step!(agent::BrainAgent, abm::Agents.ABM)::Tuple{BrainAgent, Agents.ABM}
    other_agents_posts = abm.posts[abm.posts.author_id .!= agent.id]
    if isempty(other_agents_posts)
        return agent, abm
    end
    selected_post = other_agents_posts[rand(1:length(other_agents_posts))]
    vote!(abm, agent, selected_post)
    if rand() < 0.8 # hard-coded reply probability, TODO: more sophisticated
        reply!(abm, agent, selected_post.id)
    end
    return agent, abm
end


function model_step!(abm::Agents.ABM)::Agents.ABM
    abm.step += 1
    return abm
end
