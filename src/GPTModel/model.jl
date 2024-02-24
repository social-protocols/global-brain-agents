Base.@kwdef mutable struct GPTAgent <: Agents.AbstractAgent
    id::Int
    name::String
    age::Int
    gender::String
    job::String
    traits::String
    memory::Union{DiscussionTree, Nothing}
end


function vote!(
    abm::Agents.ABM,
    agent::GPTAgent,
    post::GlobalBrainAgents.Post;
    local_testing::Bool = false,
)::Tuple{Agents.ABM, GPTAgent}
    current_vote = findlast(
        v -> v.post_id == post.id && v.user_id == agent.id,
        abm.votes
    )
    if !isnothing(current_vote)
        return abm, agent
    end

    vote = if local_testing
        Random.rand(-1:1)
    else
        get_vote_from_gpt(abm, agent, post)
    end

    if vote == 0
        return abm, agent
    end
    vote = GlobalBrainAgents.Vote(
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
    agent::GPTAgent,
    post_id::Int;
    local_testing::Bool = false,
)::Tuple{Agents.ABM, GPTAgent}
    parent_thread = get_parent_thread(abm, post_id)
    context_messages = Dict{String, String}[
        Dict(
            "role" => p.author_id == agent.id ? "system" : "user",
            "name" => abm[p.author_id].name,
            "content" => p.content
        )
        for p in parent_thread
    ]
    content = if local_testing
        Random.randstring(20)
    else
        get_reply_from_gpt(abm, agent, context_messages, 280)
    end

    new_post_id = length(abm.posts) + 1
    reply = GlobalBrainAgents.Post(
        id = new_post_id,
        parent_id = post_id,
        content = content,
        author_id = agent.id,
        timestamp = abm.step
    )
    push!(abm.posts, reply)
    add_node!(abm.discussion_tree, post_id, new_post_id)
    return abm, agent
end


function get_parent_thread(abm::Agents.ABM, post_id::Int)::Vector{GlobalBrainAgents.Post}
    post = abm.posts[post_id]
    return if isnothing(post.parent_id)
        [post]
    else
        [get_parent_thread(abm, post.parent_id); post]
    end
end


function agent_step!(agent::GPTAgent, abm::Agents.ABM)::Tuple{GPTAgent, Agents.ABM}
    score_posts!(abm, abm.discussion_tree.root)

    # Initialization case: agent has no memory and hasn't taken part in the discussion yet
    if isnothing(agent.memory)
        selected_post = abm.posts[abm.discussion_tree.root]
        # TODO: make it explicit here that agents don't vote on their own posts
        # (or already have with the OP vote)
        if agent.id != selected_post.author_id
            vote!(abm, agent, selected_post)
            reply!(abm, agent, selected_post.id)
        end
        agent.memory = DiscussionTree(abm.discussion_tree.root, [])
        return agent, abm
    end

    selected_post = choose_post_to_interact_with(agent, abm)
    vote!(abm, agent, selected_post)

    # other_agents_posts = filter(p -> p.author_id != agent.id, abm.posts)
    # if isempty(other_agents_posts)
    #     return agent, abm
    # end
    # selected_post = other_agents_posts[Random.rand(1:length(other_agents_posts))]
    # vote!(abm, agent, selected_post)
    # if Random.rand() < 0.8 # hard-coded reply probability, TODO: more sophisticated
    #     reply!(abm, agent, selected_post.id)
    # end
    return agent, abm
end

function choose_post_to_interact_with(agent::GPTAgent, abm::Agents.ABM)::GlobalBrainAgents.Post
    leaf_nodes = get_leaves(abm.discussion_tree)
    candidates = [n for n in leaf_nodes if abm.posts[n].author_id != agent.id]
    choice = Random.rand(candidates)
    return abm.posts[choice]
end


function model_step!(abm::Agents.ABM)::Agents.ABM
    abm.step += 1
    return abm
end


function create_agent_based_model(
    top_level_post::String,
    secret_key::String,
    llm::String
)::Agents.ABM
    root_post_id = 1
    root_post_author_id = 1
    root_post = GlobalBrainAgents.Post(
        id = root_post_id,
        parent_id = nothing,
        content = top_level_post,
        author_id = root_post_author_id,
        timestamp = 0,
    )
    original_poster_upvote = GlobalBrainAgents.Vote(root_post_id, root_post_author_id, true, 0)
    return Agents.ABM(
        GPTAgent;
        properties = Dict(
            :secret_key => secret_key,
            :llm => llm,
            :posts => GlobalBrainAgents.Post[root_post],
            :votes => GlobalBrainAgents.Vote[original_poster_upvote],
            :scores => GlobalBrain.ScoreData[],
            :discussion_tree => DiscussionTree(root_post_id, []),
            :step => 0,
        ),
    )
end


function populate!(abm::Agents.ABM, n_agents::Int, db::SQLite.DB)::Agents.ABM
    agents = get_gpt_agents(n_agents, db)
    for a in agents
        Agents.add_agent!(a, abm)
    end
    return abm
end
