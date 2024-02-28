library(shiny)
library(shinydashboard)
library(DBI)
library(dplyr)
library(tidyr)
library(igraph)
library(DiagrammeR)

DATA_PATH <- Sys.getenv("DATA_PATH")
DATABASE_PATH <- file.path(DATA_PATH, "social-network.db")

db <- dbConnect(RSQLite::SQLite(), DATABASE_PATH)

ui <- fluidPage(
  numericInput("post_id", "Post ID", min = 1, max = 100, step = 1, value = 1),
  tableOutput("fullData"),
  hr(),
  tableOutput("currentTreePosts"),
  grVizOutput("graphView"),
  actionButton("update", "Update")
)

server <- function(input, output, session) {
  output$fullData <- renderTable({
    scores <- dbGetQuery(db, "SELECT * FROM Score order by postId")
    scores %>% data.frame()
  })

  output$currentTreePosts <- renderTable({
    input$update
    post_id <- input$post_id
    edge_list <-
      dbGetQuery(
        db,
        "
        WITH idsRecursive AS
        (
            SELECT * FROM Score
            WHERE parentId = :post_id
            UNION ALL
            SELECT Score.* FROM Score
            JOIN idsRecursive p ON Score.parentId = p.postId
        )
        SELECT * FROM idsRecursive
        ",
        params = list(post_id = post_id)
      ) %>%
      data.frame() %>%
      filter(!is.na(parentId)) %>%
      rename(from = parentId, to = postId)

    posts <-
      dbGetQuery(db, "SELECT id as postId, content FROM Post") %>% data.frame()

    node_list <- edge_list %>%
      select(from, to) %>%
      pivot_longer(cols = c(from, to), names_to = "name", values_to = "id") %>%
      select(-name) %>%
      distinct() %>%
      left_join(posts, by = c("id" = "postId"))

    node_list
  })

  output$graphView <- renderGrViz({
    post_id <- input$post_id
    edge_list <-
      dbGetQuery(
        db,
        "
        WITH idsRecursive AS
        (
            SELECT parentId, postId, parentP, parentQ FROM Score
            WHERE parentId = :post_id
            UNION ALL
            SELECT Score.parentId, Score.postId, Score.parentP, Score.parentQ FROM Score
            JOIN idsRecursive p ON Score.parentId = p.postId
        )
        SELECT * FROM idsRecursive
        ",
        params = list(post_id = post_id)
      ) %>%
      data.frame() %>%
      rename(from = parentId, to = postId)

      edge_list$magnitude <- mapply(relative_entropy, edge_list$parentP, edge_list$parentQ)

      edge_list <-
        edge_list %>%
        mutate(
          color = if_else(
            parentP < parentQ,
            rgb(sigmoid(magnitude * 4), 0, 0),
            rgb(0, 0, sigmoid(magnitude * 4))
          )
        )

    posts <-
      dbGetQuery(db, "SELECT id as postId, content FROM Post") %>% data.frame()

    distinct_nodes <-
      edge_list %>%
      select(from, to) %>%
      pivot_longer(cols = c(from, to), names_to = "name", values_to = "id") %>%
      select(-name) %>%
      distinct()

    node_list <-
      dbGetQuery(db, "
        select postId, p, q, score
        from score
        order by postId
      ") %>%
      data.frame() %>%
      inner_join(distinct_nodes, by = c("postId" = "id")) %>%
      inner_join(posts, by = c("postId" = "postId")) %>%
      mutate(label = postId)

    print(node_list)
    print(edge_list)

    net <- create_graph() %>%
      add_nodes_from_table(
        table = node_list,
        label_col = label
      ) %>%
      add_edges_from_table(
        table = edge_list,
        from_col = from,
        to_col = to,
        from_to_map = postId
      ) %>%
      set_edge_attrs(
        edge_attr = penwidth,
        values = edge_list$magnitude * 10
      ) %>%
      set_edge_attrs(
        edge_attr = color,
        values = edge_list$color
      ) %>%
      set_edge_attrs(
        edge_attr = dir,
        values = "back"
      ) %>%
      set_node_attrs(
        node_attr = shape,
        values = "circle"
      ) %>%
      set_node_attrs(
        node_attr = tooltip,
        values = node_list$content
      ) %>%
      colorize_node_attrs(
        node_attr_from = p,
        node_attr_to = fillcolor,
        palette = "Greens"
      )

    render_graph(net, layout = "tree")
  })

}

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

shinyApp(ui, server)
