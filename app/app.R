library(shiny)
library(shinydashboard)
library(DBI)
library(dplyr)
library(tidyr)
library(igraph)
library(DiagrammeR)
library(plotwidgets)

source("helpers.R")

DATABASE_PATH <- file.path(Sys.getenv("DATA_PATH"), "social-network.db")
SIM_DATABASE_PATH <- Sys.getenv("SIM_DATABASE_PATH")

ui <- dashboardPage(
  skin = "black",
  dashboardHeader(title = "Global Brain"),
  dashboardSidebar(
    sidebarMenu(
      menuItem("Interactive", tabName = "interactive"),
      menuItem("Simulation", tabName = "simulation")
    )
  ),
  dashboardBody(
    tabItems(
      tabItem(
        tabName = "interactive",
        fluidPage(
          fluidRow(
            # column(width = 6,
            #   selectInput("database", "Database", c(DATABASE_PATH, SIM_DATABASE_PATH), selected = SIM_DATABASE_PATH, width = "100%"),
            # ),
            column(width = 1,
              numericInput("tag_id", "Tag ID", min = 1, max = 100, step = 1, value = 2, width = "100%"),
            ),
            column(width = 1,
              numericInput("post_id", "Post ID", min = 1, max = 100, step = 1, value = 1, width = "100%")
            )
          ),
          h1("Discussion Tree"),
          dataTableOutput("scoreDataTree"),
          hr(),
          grVizOutput("discussionTreeGraph"),
          # tableOutput("fullData"),
          # hr(),
          # tableOutput("currentTreePosts"),
          # grVizOutput("graphView"),
          actionButton("update", "Update")
        )
      ),
      tabItem(
        tabName = "simulation",
        fluidPage(h1("halo i bims")),
      )
    )
  ),
)

server <- function(input, output, session) {
  prototype_db <- reactive({ dbConnect(RSQLite::SQLite(), SIM_DATABASE_PATH) })
  
  posts <- reactive({
    input$update
    input$database
    input$tag_id
    con <- prototype_db()
    dbGetQuery(con, "select * from Post") %>% data.frame()
  })
  
  score_data_tree <- reactive({
    input$update
    root_post_id <- input$post_id
    tag_id <- input$tag_id
    db <- prototype_db()
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
  })
  
  output$scoreDataTree <- renderDataTable({
    score_data_tree()
  })

  output$discussionTreeGraph <- renderGrViz({
    con <- prototype_db()
    tag_id <- input$tag_id
    score_data <- score_data_tree()
    
    edges <- score_data %>% 
      select(parentId, postId, parentP, parentQ) %>% 
      filter(!is.na(parentId)) %>% 
      mutate(
        penwidth = mapply(relative_entropy, parentP, parentQ),
        penwidth = if_else(
          is.na(penwidth),
          0,
          penwidth * 0.5 # TODO: better scaling
        ),
        color = if_else(
          parentP < parentQ,
          rgb(sigmoid(penwidth * 4), 0, 0),
          rgb(0, 0, sigmoid(penwidth * 4))
        )
      )
    
    nodes <- score_data %>% 
      select(postId, parentId) %>%
      pivot_longer(cols = c(parentId, postId), names_to = "name", values_to = "postId") %>% 
      filter(!is.na(postId)) %>% 
      select(postId) %>% 
      left_join(score_data %>% select(postId, p), by = c("postId" = "postId")) %>% 
      distinct() %>% 
      mutate(
        label = postId,
        fillcolor = vectorized_hsl2col(p)
      )
      
    net <- create_graph() %>% 
      add_nodes_from_table(nodes) %>% 
      add_edges_from_table(edges, from_col = parentId, to_col = postId, from_to_map = postId) %>% 
      set_edge_attrs(edge_attr = dir, values = "back")
    
    # TODO:
    # - [ ] map node size to participation
    
    render_graph(net, layout = "tree")
  })
  
  # output$graphView <- renderGrViz({
  #   db <- db()
  #   tag_id <- input$tag_id
  #   score_data <- score_data_tree()
  #   
  #   edges <- score_data %>%
  #     select()
  # 
  #   edges <- get_edges() %>%
  #     mutate(
  #       penwidth = mapply(relative_entropy, parentP, parentQ),
  #       penwidth = if_else(
  #         is.na(penwidth),
  #         0,
  #         penwidth * 0.5
  #       )
  #     ) %>%
  #     mutate(
  #       color = if_else(
  #         parentP < parentQ,
  #         rgb(sigmoid(penwidth * 4), 0, 0),
  #         rgb(0, 0, sigmoid(penwidth * 4))
  #       )
  #     )
  # 
  #   distinct_nodes <-
  #     edges %>%
  #     select(from, to) %>%
  #     pivot_longer(cols = c(from, to), names_to = "name", values_to = "id") %>%
  #     select(-name) %>%
  #     distinct()
  # 
  #   nodes <-
  #     dbGetQuery(db, "
  #       select postId, p, q, score
  #       from score
  #       where tagId = :tag_id
  #       order by postId
  #     ", params = list("tag_id" = tag_id)) %>%
  #     data.frame() %>%
  #     inner_join(distinct_nodes, by = c("postId" = "id")) %>%
  #     mutate(
  #       label = postId,
  #       fillcolor = vectorized_hsl2col(p)
  #     )
  # 
  #   if (input$database == DATABASE_PATH) {
  #     posts <- posts() %>% filter(postId == input$post_id)
  #     nodes <- nodes %>% left_join(posts, by = c("postId" = "postId"))
  #   }
  # 
  #   net <- create_graph() %>%
  #     add_nodes_from_table(table = nodes, label_col = label) %>%
  #     add_edges_from_table(
  #       table = edges,
  #       from_col = from,
  #       to_col = to,
  #       from_to_map = postId,
  #     ) %>%
  #     set_edge_attrs(edge_attr = dir, values = "back")
  # 
  #   if (input$database == DATABASE_PATH) {
  #     net <- net %>%
  #       set_node_attrs(node_attr = tooltip, values = nodes$content)
  #   }
  # 
  #   render_graph(net, layout = "tree")
  # })
  
  session$onSessionEnded(stopApp)

}

shinyApp(ui, server)