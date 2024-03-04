library(DBI)
library(dplyr)
library(tidyr)
library(shiny)
library(DiagrammeR)

SIM_DATABASE_PATH <- Sys.getenv("SIM_DATABASE_PATH")

simulationVisualizerUI <- function(id) {
  fluidPage(
    h1("Simulation"),
    dataTableOutput(NS(id, "scoreGraphTest")),
    grVizOutput(NS(id, "discussionTreeGraph")),
  )
}

simulationVisualizerServer <- function(id) {
  moduleServer(id, function(input, output, session) {
    simulation_db <- function() {
      dbConnect(RSQLite::SQLite(), SIM_DATABASE_PATH)
    }

    scoreDataTree <- reactive({
      input$update
      root_post_id <- 1
      tag_id <- 3 # TODO: fix in simulations
      con <- simulation_db()
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

    output$scoreGraphTest <- renderDataTable({
      scoreDataTree()
    })

    output$discussionTreeGraph <- renderGrViz({
      tag_id <- 3
      score_data <- scoreDataTree()
      net <- note_effect_graph(score_data)
      render_graph(net, layout = "tree")
    })
  })
}
