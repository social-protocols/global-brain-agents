surprisal <- function(p, unit = 2) {
  return(log(1 / p, unit))
}

entropy <- function(p) {
  if (p == 1) {
    return(0)
  }
  return(p * surprisal(p, 2) + (1 - p) * surprisal(1 - p, 2))
}

cross_entropy <- function(p, q, unit = 2) {
  if (((p == 1) && (q == 1)) || ((p == 0) && (q == 0))) {
    return(0)
  }
  return(p * surprisal(q, unit) + (1 - p) * surprisal(1 - q, unit)) 
}

relative_entropy <- function(p, q) {
  return(cross_entropy(p, q) - entropy(p))
}

sigmoid <- function(x) {
  return(1 / (1 + exp(-x)))
}

vectorized_hsl2col <- function(p) {
  vct <- function(e) {
    return(c(120, e, 0.7))
  }
  vecs <- lapply(p, vct)
  mtxs <- lapply(vecs, matrix)
  cols <- lapply(mtxs, hsl2col)
  return(unlist(cols))
}

scale_zero_inf_to_range <- function(x, scale_factor, min, max) {
  zero_one <- 1 - (1 / (scale_factor * x + 1))
  return(zero_one * (max - min) + min)
}

note_effect_graph <- function(score_data) {
    edges <-
      score_data %>% 
      select(parentId, postId, parentP, parentQ) %>% 
      filter(!is.na(parentId))

    max_sample_size <- max(score_data$sampleSize)

    nodes <-
      score_data %>% 
      select(postId, p, sampleSize) %>% 
      mutate(
        label = postId,
        fillcolor = vectorized_hsl2col(p),
        height =
          scale_zero_inf_to_range(sampleSize, 1 / max_sample_size, 0.2, 1.1)
      )

    net <- create_graph() 

    if (nrow(nodes) != 0) {
      net <- net %>% add_nodes_from_table(nodes, label_col = label)
    }

    if (nrow(edges) != 0) {
      edges <- edges %>% 
        mutate(
          effect_on_parent_magnitude =
            mapply(relative_entropy, parentP, parentQ),
          stance_toward_parent = if_else(
            parentP < parentQ,
            rgb(sigmoid(effect_on_parent_magnitude * 4), 0, 0),
            rgb(0, 0, sigmoid(effect_on_parent_magnitude * 4))
          ),
          # map to edge attributes
          penwidth = scale_zero_inf_to_range(
            effect_on_parent_magnitude,
            1.0,
            0.5,
            5
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
        set_edge_attrs(edge_attr = dir, values = "back")
    }
    
    return(net)
}
