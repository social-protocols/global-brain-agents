library(dplyr)
library(plotwidgets)
library(DiagrammeR)

surprisal <- function(p, unit = 2) {
  # unit determines the unit of information at which we measure surprisal
  # base 2 is the default and it measures information in bits
  return(log(1 / p, unit))
}

entropy <- function(p) {
  return(
    ifelse(
      p == 1,
      0,
      p * surprisal(p, 2) + (1 - p) * surprisal(1 - p, 2)
    )
  )
}

cross_entropy <- function(p, q, unit = 2) {
  return(
    ifelse(
      ((p == 1) & (q == 1)) | ((p == 0) & (q == 0)),
      0,
      p * surprisal(q, unit) + (1 - p) * surprisal(1 - q, unit)
    )
  )
}

relative_entropy <- function(p, q) {
  return(cross_entropy(p, q) - entropy(p))
}

sigmoid <- function(x) {
  return(1 / (1 + exp(-x)))
}

hsl2col_vectorized <- function(p) {
  vct <- function(p) {
    sat <- scale_to_range(p, 0.0, 1.0, 0.0, 1.0)
    lum <- 1.0 - scale_to_range(p, 0.0, 1.0, 0.1, 0.4)
    return(c(220, sat, lum))
  }
  vecs <- lapply(p, vct)
  mtxs <- lapply(vecs, matrix)
  cols <- lapply(mtxs, hsl2col)
  return(unlist(cols))
}

scale_to_range <- function(x, from_min, from_max, to_min, to_max) {
  return(
    (x - from_min) / (from_max - from_min)
    * (to_max - to_min)
    + to_min
  )
}

note_effect_graph <- function(score_data, posts, show_content = FALSE) {
  edges <- score_data %>%
    select(parentId, postId, parentP, parentQ) %>%
    filter(!is.na(parentId))

  min_sample_size <- min(score_data$sampleSize)
  max_sample_size <- max(score_data$sampleSize)

  nodes <- score_data %>%
    select(postId, p, sampleSize) %>%
    mutate(
      label = postId,
      fillcolor = hsl2col_vectorized(p),
    )

  if (!show_content) {
    nodes <- nodes %>%
      mutate(
        height = scale_to_range(
          sampleSize,
          min_sample_size, max_sample_size,
          0.3, 0.8
        ),
        width = scale_to_range(
          sampleSize,
          min_sample_size, max_sample_size,
          0.3, 0.8
        ),
      )
  }

  if (show_content) {
    nodes <- nodes %>%
      left_join(
        posts %>% select(id, content),
        by = c("postId" = "id")
      ) %>%
      mutate(content = substr(content, 1, 100))
  }

  net <- create_graph()

  if (nrow(nodes) != 0) {
    net <- net %>%
      add_nodes_from_table(nodes, label_col = label)

    if (show_content) {
      net <- net %>%
        set_node_attr_to_display(attr = content) %>%
        set_node_attrs(node_attr = shape, values = "rectangle") %>%
        set_node_attrs(node_attr = fixedsize, values = TRUE) %>%
        set_node_attrs(node_attr = width, values = 2.0)
    }
  }

  if (nrow(edges) != 0) {
    edges <- edges %>%
      mutate(
        effect_on_parent_magnitude =
          mapply(relative_entropy, parentP, parentQ),
        stance_toward_parent = if_else(
          parentP < parentQ,
          "red", "forestgreen"
          # rgb(sigmoid(effect_on_parent_magnitude * 4), 0, 0),
          # rgb(0, sigmoid(effect_on_parent_magnitude * 4), 0)
        )
      )

    min_effect_on_parent_magnitude <- min(edges$effect_on_parent_magnitude)
    max_effect_on_parent_magnitude <- max(edges$effect_on_parent_magnitude)

    edges <- edges %>%
      # map to edge attributes
      mutate(
        penwidth = scale_to_range(
          effect_on_parent_magnitude,
          min_effect_on_parent_magnitude, max_effect_on_parent_magnitude,
          1.0, 5.0
        ),
        color = stance_toward_parent
      )

    net <- net %>%
      add_edges_from_table(
        edges,
        from_col = parentId,
        to_col = postId,
        from_to_map = postId
      ) %>%
      set_edge_attrs(edge_attr = dir, values = "back") %>%
      set_edge_attrs(edge_attr = len, values = 3.0)
  }

  return(net)
}
