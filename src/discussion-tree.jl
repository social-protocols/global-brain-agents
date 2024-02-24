struct DiscussionTree
    root::Int
    edges::Vector{Tuple{Int, Int}}
end


function nodes(tree::DiscussionTree)::Vector{Int}
    if isempty(tree.edges)
        return [tree.root]
    end
    return unique(Iterators.flatten(tree.edges))
end


function descendents(tree::DiscussionTree, post_id::Int)::Vector{Int}
    out_edges = filter((e) -> e[1] == post_id, tree.edges)
    return [e[2] for e in out_edges]
end


function add_node!(tree::DiscussionTree, parent_id::Int, post_id::Int)::DiscussionTree
    if post_id in nodes(tree)
        error("Post $post_id already exists in the discussion tree")
    end
    push!(tree.edges, (parent_id, post_id))
    return tree
end


function get_leaves(tree::DiscussionTree)::Vector{Int}
    return filter((n) -> isempty(descendents(tree, n)), nodes(tree))
end
