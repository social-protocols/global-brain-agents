

# generic vote! function
# generic reply! function

# dummy agent_step! function
# dummy model_step! function



# --- Rational Model

# TODO: generic function
function create_agent_based_model(config::RationalConfig)::Agents.ABM
    root_post_id = 1
    root_post_author_id = 1
    root_post = RationalPost(
        id = root_post_id,
        parent_id = nothing,
        content = config.top_level_post,
        author_id = root_post_author_id,
        timestamp = 0,
    )
    original_poster_upvote = GlobalBrainAgents.Vote(root_post_id, root_post_author_id, true, 0)

    properties = properties = Dict(
        :posts => RationalPost[root_post],
        :votes => GlobalBrainAgents.Vote[original_poster_upvote],
        :scores => GlobalBrain.ScoreData[],
        :discussion_tree => DiscussionTree(root_post_id, []),
        :step => 0,
    )

    abm = Agents.ABM(RationalAgent; properties = properties)

    for i in 1:config.n_agents
        a = RationalAgent(
            id = i,
            belief = 0.5,
            weight = 1.0,
            observation = true,
            memory = nothing,
        )
        Agents.add_agent!(a, abm)
    end

    return abm
end


# --- GPT Model

function create_agent_based_model(
    top_level_post::String,
    secret_key::String,
    llm::String
)::Agents.ABM
    root_post_id = 1
    root_post_author_id = 1
    root_post = GPTPost(
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
            :posts => GPTPost[root_post],
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


function agent_step!(agent::RationalAgent, abm::Agents.ABM)::Agents.ABM
    println(agent)
    return abm
end

