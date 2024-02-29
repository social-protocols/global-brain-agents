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
