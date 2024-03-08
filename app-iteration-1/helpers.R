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
