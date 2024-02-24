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


struct PostDetailsView
    post::GlobalBrainAgents.Post
    thread::Vector{GlobalBrainAgents.Post}
    scored_replies::Vector{Tuple{GlobalBrainAgents.Post, GlobalBrain.ScoreData}}
end

