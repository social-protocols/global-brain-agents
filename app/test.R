library(shiny)
library(shinydashboard)
library(DBI)
library(dplyr)
library(tidyr)
library(igraph)
library(DiagrammeR)
library(plotwidgets)

source("app/helpers.R")

DATABASE_PATH <- file.path(Sys.getenv("DATA_PATH"), "social-network.db")
SIM_DATABASE_PATH <- Sys.getenv("SIM_DATABASE_PATH")


db <- dbConnect(RSQLite::SQLite(), SIM_DATABASE_PATH)

# score_data_tree

root_post_id <- 1
tag_id <- 2
score_data <-
  dbGetQuery(
    db,
    "
      with tagInView as (
        select *
        from score
        where tagId = :tag_id
      )
      , idsRecursive AS (
        SELECT *
        FROM tagInView
        WHERE postId = :root_post_id
        UNION ALL
        SELECT tagInView.*
        FROM tagInView
        JOIN idsRecursive p
        ON tagInView.parentId = p.postId
      )
      SELECT * FROM idsRecursive
    ",
    params = list(root_post_id = root_post_id, tag_id = tag_id)
  ) %>%
  data.frame()

edges <- score_data %>% 
  select(parentId, postId) %>% 
  filter(!is.na(parentId))
nodes <- edges %>% 
  pivot_longer(cols = c(parentId, postId), names_to = "name", values_to = "postId") %>% 
  select(postId) %>% 
  distinct()
net <- create_graph() %>% 
  add_nodes_from_table(nodes) %>% 
  add_edges_from_table(edges, from_col = parentId, to_col = postId, from_to_map = postId)


# full data

tag_id <- 1
scores <- dbGetQuery(
  db,
  "select * from Score where tagId = :tag_id order by postId",
  params = list("tag_id" = tag_id)
)
scores %>% data.frame()
