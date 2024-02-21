function score_posts!(abm::Agents.ABM, root_post_id::Int)::Agents.ABM
    in_memory_tree = construct_inmemory_tree(abm, root_post_id)
    tallies_tree_iterable = to_tallies_tree_iterable(in_memory_tree)
    abm.scores = GlobalBrain.score_tree(tallies_tree_iterable)
    return abm
end

function construct_inmemory_tree(abm::Agents.ABM, root_post_id::Int)::GlobalBrain.InMemoryTree
    children_posts = filter(p -> p.parent_id == root_post_id, abm.posts)
    detailed_tally = get_detailed_tally(abm, root_post_id)
    children = [construct_inmemory_tree(abm, p.id) for p in children_posts]
    return GlobalBrain.InMemoryTree(detailed_tally, children)
end

function get_detailed_tally(abm::Agents.ABM, post_id::Int)::GlobalBrain.DetailedTally
    parent_id = abm.posts[post_id].parent_id
    parent_votes = filter(v -> v.post_id == parent_id, abm.votes)
    post_votes = filter(v -> v.post_id == post_id, abm.votes)
    parent_informed_user_ids = Set([v.user_id for v in parent_votes])
    post_informed_user_ids = Set([v.user_id for v in post_votes])
    informed_users = intersect(parent_informed_user_ids, post_informed_user_ids)
    uninformed_users = setdiff(parent_informed_user_ids, post_informed_user_ids)

    # TODO: should be empty -> handle in model
    # ------>
    # incompletely_informed_users = setdiff(post_informed_user_ids, parent_informed_user_ids)
    # println(incompletely_informed_users)
    # <------

    post_informed_votes = filter(v -> v.user_id in informed_users, post_votes)
    post_uninformed_votes = filter(v -> v.user_id in uninformed_users, post_votes)

    parent_tally = GlobalBrain.BernoulliTally(
        length(filter(v -> v.upvote, parent_votes)),
        length(parent_votes),
    )
    informed_tally = GlobalBrain.BernoulliTally(
        length(filter(v -> v.upvote, post_informed_votes)),
        length(post_informed_votes),
    )
    uninformed_tally = GlobalBrain.BernoulliTally(
        length(filter(v -> v.upvote, post_uninformed_votes)),
        length(post_uninformed_votes),
    )
    self_tally = GlobalBrain.BernoulliTally(
        length(filter(v -> v.upvote, post_votes)),
        length(post_votes),
    )

    return DetailedTally(
        tag_id = 1,
        parent_id = parent_id,
        post_id = post_id,
        parent = parent_tally,
        uninformed = uninformed_tally,
        informed = informed_tally,
        self = self_tally,
    )
end

function to_tallies_tree_iterable(tree::InMemoryTree)::Vector{TalliesTree}
    flat_tree = flatten_tree(tree)
    tallies_trees = TalliesTree.(flat_tree)
    return tallies_trees
end

function flatten_tree(t::InMemoryTree)::Vector{InMemoryTree}
    if isempty(t.children)
        return [t]
    end
    return [t; mapreduce(flatten_tree, vcat, t.children)]
end


