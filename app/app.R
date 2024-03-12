library(shiny)
library(shinydashboard)
library(DBI)
library(dplyr)
library(tidyr)
library(r2d3)

source("helpers.R")
source("simulation-demo.R")

PROTOTYPE_DATABASE_PATH <- Sys.getenv("PROTOTYPE_DATABASE_PATH")
SERVICE_DATABASE_PATH <- Sys.getenv("SERVICE_DATABASE_PATH")
SIM_DATABASE_PATH <- Sys.getenv("SIM_DATABASE_PATH")

ui <- dashboardPage(
  skin = "black",
  dashboardHeader(title = "Global Brain"),
  dashboardSidebar(
    sidebarMenu(
      # menuItem("Interactive", tabName = "interactive-demo"),
      menuItem("Simulation", tabName = "simulation-demo")
    )
  ),
  dashboardBody(
    # tags$head(
    #   tags$style(HTML(".content-wrapper { background-color: #FFFFFF }"))
    # ),
    tabItems(
      # tabItem(tabName = "interactive-demo",
      #   fluidPage(
      #       fluidRow(
      #         column(width = 2,
      #           numericInput(
      #             "postId", "Post ID",
      #             min = 1, max = 100, step = 1, value = 1
      #           ),
      #         ),
      #       ),
      #       fluidRow(d3Output("algoVisualization", width = "100%", height = "1600px"))
      #   )
      # ),
      tabItem(tabName = "simulation-demo",
        simulationVisualizerUI("simulationVisualizer")
      )
    )
  ),
)

server <- function(input, output, session) {
    simulationVisualizerServer("simulationVisualizer")

    prototype_db <- function() {
      dbConnect(RSQLite::SQLite(), PROTOTYPE_DATABASE_PATH)
    }

    service_db <- function() {
      dbConnect(RSQLite::SQLite(), SERVICE_DATABASE_PATH)
    }

    discussionTree <- reactivePoll(
      intervalMillis = 1000,
      session,
      checkFunc = function() {
        con <- prototype_db()
        check_data <-
          dbGetQuery(con, "SELECT MAX(voteEventId) FROM Score") %>% data.frame()
        dbDisconnect(con)
        check_data
      },
      valueFunc = function() {
        root_post_id <- input$postId
        con <- prototype_db()
        data <-
          dbGetQuery(
            con,
            "
              WITH idsRecursive AS (
                SELECT *
                FROM post
                WHERE id = :root_post_id
                UNION ALL
                SELECT p2.*
                FROM post p2
                JOIN idsRecursive ON p2.parentId = idsRecursive.id
              )
              SELECT idsRecursive.*,
                voteEventId -- TODO: rename to lastVoteEventId or similar
                , voteEventTime
                , topNoteId
                , o
                , oCount
                , oSize
                , p
                , score
              FROM idsRecursive
              LEFT OUTER JOIN score ON idsRecursive.id = score.postId
            ",
            params = list(root_post_id = root_post_id)
          ) %>%
          data.frame() %>%
          mutate(parentId = if_else(id == root_post_id, NA, parentId)) %>%
          rename(postId = id) # TODO: rename in table to postId
        dbDisconnect(con)
        data
      }
    )

    posts <- reactivePoll(
      intervalMillis = 1000,
      session,
      checkFunc = function() {
        con <- prototype_db()
        check_data <-
          dbGetQuery(con, "SELECT MAX(id) FROM Post") %>% data.frame()
        dbDisconnect(con)
        check_data
      },
      valueFunc = function() {
        con <- prototype_db()
        data <- dbGetQuery(con, "SELECT * FROM Post") %>% data.frame()
        dbDisconnect(con)
        data
      }
    )

    scoreEvents <- reactive({
      input$postId
      con <- prototype_db()
      data <- dbGetQuery(con, "SELECT * FROM ScoreEvent") %>% data.frame()
      dbDisconnect(con)
      data
    })

    voteEvents <- reactive({
      input$postId
      con <- prototype_db()
      data <- dbGetQuery(con, "SELECT * FROM VoteEvent") %>% data.frame()
      dbDisconnect(con)
      data
    })

    detailedTallies <- reactive({
      con <- service_db()
      data <- dbGetQuery(con, "SELECT * FROM DetailedTally") %>% data.frame()
      dbDisconnect(con)
      data
    })

    noteEffects <- reactive({
      con <- prototype_db()
      tree <- discussionTree()
      data <- dbGetQuery(con, "SELECT * FROM effect") %>%
        data.frame() %>%
        filter(postId %in% tree$postId | noteId %in% tree$postId) %>%
        mutate(magnitude = relative_entropy(p, q))
      dbDisconnect(con)
      data
    })

    output$algoVisualization <- renderD3({
      score_events <- scoreEvents()
      vote_events <- voteEvents()

      note_effects <- noteEffects()
      discussion_tree <- discussionTree()

      print(discussion_tree)
      print(note_effects)

      discussion_tree_json <- data_to_json(discussion_tree)
      note_effects_json <- data_to_json(note_effects)
      score_events_json <- data_to_json(score_events)
      vote_events_json <- data_to_json(vote_events)

      r2d3(
        data = list(
          discussion_tree = discussion_tree_json,
          note_effects = note_effects_json,
          score_events = score_events_json,
          vote_events = vote_events_json
        ),
        script = "algorithm-visualization.js"
      )
    })
}

shinyApp(ui, server)
