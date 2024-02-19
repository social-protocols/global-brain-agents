tools = Dict{String, Any}[
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
]
