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
  grVizOutput("graphView"),
)

server <- function(input, output, session) {
  output$fullData <- renderTable({
    test_data <- dbGetQuery(db, "SELECT * FROM ScoreData")
    test_data %>% data.frame() %>% head()
  })

  output$graphView <- renderGrViz({
    post_id <- input$post_id
    edge_list <-
      dbGetQuery(
        db,
        "
        WITH idsRecursive AS
        (
            SELECT postId, parentId, parentP FROM ScoreData
            WHERE parentId = :post_id
            UNION ALL
            SELECT ScoreData.postId, ScoreData.parentId, ScoreData.parentP FROM ScoreData
            JOIN idsRecursive p ON ScoreData.parentId = p.postId
        )
        SELECT * FROM idsRecursive
        ",
        params = list(post_id = post_id)
      ) %>%
      data.frame() %>%
      filter(!is.na(parentId)) %>%
      rename(from = parentId, to = postId)

    node_list <- edge_list %>%
      select(from, to) %>%
      pivot_longer(cols = c(from, to), names_to = "name", values_to = "id") %>%
      select(-name) %>%
      distinct() %>%
      mutate(label = id)

    print(node_list)
    print(edge_list)

    net <- create_graph() %>%
      add_nodes_from_table(
        node_list,
        label_col = label
      ) %>%
      add_edges_from_table(
        edge_list,
        from_col = from,
        to_col = to,
        from_to_map = id_external
      ) %>%
      set_edge_attrs(
        edge_attr = color,
        values = "black"
      ) %>%
      set_edge_attrs(
        edge_attr = penwidth,
        values = edge_list$parentP * 2
      )

    render_graph(net)
  })

}

shinyApp(ui, server)
