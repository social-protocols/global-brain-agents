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
    tags$head(
      tags$style(
        HTML(".content-wrapper { background-color: #ffffff }")
      )
    ),
    tabItems(
      tabItem(
        tabName = "interactive",
        fluidPage(
          fluidRow(
            column(
              width = 2,
              numericInput(
                "tagId",
                "Tag ID",
                min = 1,
                max = 100,
                step = 1,
                value = 1, # should be tag "global"
                width = "100%"
              ),
            ),
            column(
              width = 2,
              numericInput(
                "postId",
                "Post ID",
                min = 1,
                max = 100,
                step = 1,
                value = 1,
                width = "100%"
              )
            )
          ),
          h1("Discussion Tree"),
          dataTableOutput("scoreDataTree"),
          hr(),
          grVizOutput("discussionTreeGraph", width = "100%", height = "400px"),
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
  prototype_db <- function() {
    dbConnect(RSQLite::SQLite(), DATABASE_PATH)
  }

  posts <- reactive({
    input$update
    input$database
    input$tagId
    con <- prototype_db()
    data <- dbGetQuery(con, "SELECT * FROM Post") %>% data.frame()
    dbDisconnect(con)
    data
  })

  score_data_tree <- reactive({
    input$update
    root_post_id <- input$postId
    tag_id <- input$tagId
    con <- prototype_db()
    data <-
      dbGetQuery(
        con,
        "
          WITH tagInView AS (
            SELECT *
            FROM score
            WHERE tagId = :tag_id
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
      data.frame() %>% 
      mutate(parentId = if_else(postId == root_post_id, NA, parentId))
    dbDisconnect(con)
    data
  })

  output$scoreDataTree <- renderDataTable({ score_data_tree() })

  output$discussionTreeGraph <- renderGrViz({
    tag_id <- input$tagId
    score_data <- score_data_tree()
    
    edges <-
      score_data %>% 
      select(
        parentId,
        postId,
        parentP,
        parentQ
      ) %>% 
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
      edges <-
        edges %>% 
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
      
      net <-
        net %>% 
        add_edges_from_table(
          edges,
          from_col = parentId,
          to_col = postId,
          from_to_map = postId
        ) %>% 
        set_edge_attrs(edge_attr = dir, values = "back")
    }
    
    render_graph(net, layout = "tree")
  })
  
  session$onSessionEnded(stopApp)

}

shinyApp(ui, server)