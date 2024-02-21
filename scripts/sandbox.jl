using GlobalBrain

tree = InMemoryTree(
    DetailedTally(
        1, nothing, 1,
        BernoulliTally(1, 1),
        BernoulliTally(1, 1),
        BernoulliTally(1, 1),
        BernoulliTally(1, 1),
    ),
    [
        InMemoryTree(
            DetailedTally(
                2, 1, 2,
                BernoulliTally(1, 1),
                BernoulliTally(1, 1),
                BernoulliTally(1, 1),
                BernoulliTally(1, 1),
            ),
            [
                InMemoryTree(
                    DetailedTally(
                        4, 2, 4,
                        BernoulliTally(1, 1),
                        BernoulliTally(1, 1),
                        BernoulliTally(1, 1),
                        BernoulliTally(1, 1),
                    ),
                    [
                        InMemoryTree(
                            DetailedTally(
                                6, 2, 6,
                                BernoulliTally(1, 1),
                                BernoulliTally(1, 1),
                                BernoulliTally(1, 1),
                                BernoulliTally(1, 1),
                            ),
                            []
                        ),
                    ]
                ),
                InMemoryTree(
                    DetailedTally(
                        5, 2, 5,
                        BernoulliTally(1, 1),
                        BernoulliTally(1, 1),
                        BernoulliTally(1, 1),
                        BernoulliTally(1, 1),
                    ),
                    []
                ),
            ]
        ),
        InMemoryTree(
            DetailedTally(
                3, 1, 3,
                BernoulliTally(1, 1),
                BernoulliTally(1, 1),
                BernoulliTally(1, 1),
                BernoulliTally(1, 1),
            ),
            []
        ),
    ]
)

function flatten_tree(t::InMemoryTree)
    if isempty(t.children)
        return [t]
    end
    return [t; mapreduce(flatten_tree, vcat, t.children)]
end

flat_tree = flatten_tree(tree)
tallies_trees = TalliesTree.(flat_tree)
score_tree(tallies_trees)

