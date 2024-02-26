abstract type AbstractPost end

Base.@kwdef struct GPTPost <: AbstractPost
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
    post::AbstractPost
    thread::Vector{AbstractPost}
    scored_replies::Vector{Tuple{AbstractPost, GlobalBrain.ScoreData}}
end

