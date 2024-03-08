library(shiny)
library(DBI)
library(dplyr)
library(tidyr)
library(r2d3)

source("helpers.R")

PROTOTYPE_DATABASE_PATH <- Sys.getenv("PROTOTYPE_DATABASE_PATH")
SERVICE_DATABASE_PATH <- Sys.getenv("SERVICE_DATABASE_PATH")
SIM_DATABASE_PATH <- Sys.getenv("SIM_DATABASE_PATH")

ui <- fluidPage(
    fluidRow(
      column(width = 2,
        numericInput(
          "postId", "Post ID",
          min = 1, max = 100, step = 1, value = 1
        ),
      ),
    ),
    fluidRow(d3Output("algoVisualization", width = "100%", height = "1600px"))
)

server <- function(input, output, session) {
    prototype_db <- function() {
      dbConnect(RSQLite::SQLite(), PROTOTYPE_DATABASE_PATH)
    }

    sim_db <- function() {
      dbConnect(RSQLite::SQLite(), SIM_DATABASE_PATH)
    }

    service_db <- function() {
      dbConnect(RSQLite::SQLite(), SERVICE_DATABASE_PATH)
    }

    scoreDataTree <- reactivePoll(
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
        tag_id <- 1 # global
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

    output$algoVisualization <- renderD3({
      posts <- posts() %>% select(id, content)
      detailed_tallies <- detailedTallies() %>%
        select(
          parentId, postId,
          uninformedCount, uninformedTotal,
          informedCount, informedTotal
        )
      scores <- scoreDataTree() %>%
        mutate(effect_on_parent = relative_entropy(parentP, parentQ)) %>%
        left_join(posts, by = c("postId" = "id")) %>%
        left_join(
          detailed_tallies,
          by = c("postId" = "parentId", "topNoteId" = "postId")
        ) %>%
        identity()
      score_events <- scoreEvents()
      vote_events <- voteEvents()

      score_events_json <- data_to_json(score_events)
      score_data_json <- data_to_json(scores)
      vote_events_json <- data_to_json(vote_events)

      r2d3(
        data = list(
          score_data = score_data_json,
          score_events = score_events_json,
          vote_events = vote_events_json
        ),
        script = "algorithm-visualization.js"
      )
    })
}

shinyApp(ui, server)
