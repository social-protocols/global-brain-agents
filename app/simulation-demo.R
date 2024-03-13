library(shiny)
library(r2d3)
library(DBI)
library(dplyr)

SIM_DATABASE_PATH <- Sys.getenv("SIM_DATABASE_PATH")

source("helpers.R")
source("database.R")

simulationDemoUI <- function(id) {
  fluidPage(
    # TODO: input from UI -> which simulation -> min post id
    selectInput(
      NS(id, "tagId"), "Simulation ID",
      choices = c(1, 2, 3, 4, 5), selected = 1
    ), # TODO
    uiOutput(NS(id, "postIdSelector")),
    d3Output(NS(id, "algoVisualization")),
  )
}

simulationDemoServer <- function(id) {
  moduleServer(id, function(input, output, session) {

    output$postIdSelector <- renderUI({
      tag_id <- input$tagId
      con <- simulation_db()
      choices <-
        dbGetQuery(
          con,
          "SELECT distinct post_id FROM VoteEvent WHERE tag_id = :tag_id",
          params = list(tag_id = tag_id)
        ) %>%
        data.frame() %>%
        pull()
      selectInput(
        NS(id, "postId"), "Post ID",
        choices = choices, selected = 1
    # --------------------------------------
    # --- Data -----------------------------
    # --------------------------------------

    score_events <- get_score_events() %>%
        rename(
          voteEventId = vote_event_id,
          voteEventTime = vote_event_time,
          tagId = tag_id,
          postId = post_id,
          topNoteId = top_note_id,
          o = o,
          oCount = o_count,
          oSize = o_size,
          p = p,
          score = score,
        )

    vote_events <- get_vote_events() %>%
      rename(
        voteEventId = vote_event_id,
        voteEventTime = vote_event_time,
        userId = user_id,
        tagId = tag_id,
        parentId = parent_id,
        postId = post_id,
        noteId = note_id,
        vote = vote,
      )

    effect_events <- get_effect_events() %>%
      rename(
        voteEventId = vote_event_id,
        voteEventTime = vote_event_time,
        tagId = tag_id,
        postId = post_id,
        noteId = note_id,
        p = p,
        q = q,
        r = r,
        pCount = p_count,
        qCount = q_count,
        rCount = r_count,
        pSize = p_size,
        qSize = q_size,
        rSize = r_size,
      )

    discussionTree <- reactive({
      root_post_id <- input$postId
      con <- simulation_db()
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
              JOIN idsRecursive ON p2.parent_id = idsRecursive.id
            )
            SELECT idsRecursive.*,
              vote_event_id -- TODO: rename to lastVoteEventId or similar
              , vote_event_time
              , top_note_id
              , o
              , o_count
              , o_size
              , p
              , score
            FROM idsRecursive
            LEFT OUTER JOIN score ON idsRecursive.id = score.post_id
          ",
          params = list(root_post_id = root_post_id)
        ) %>%
        data.frame() %>%
        mutate(parent_id = if_else(id == root_post_id, NA, parent_id)) %>%
        rename(post_id = id) # TODO: rename in table to postId
      dbDisconnect(con)
      data
    })

    effects <- reactive({
      tag_id <- input$tagId
      period <- input$period
      con <- simulation_db()
      data <- dbGetQuery(
        con,
        "
          SELECT MAX(vote_event_id) AS max_id, *
          FROM EffectEvent
          WHERE tag_id = :tag_id
          AND vote_event_time <= :period
          GROUP BY post_id, note_id
        ",
        params = list(tag_id = tag_id, period = period)
      ) %>%
        data.frame() %>%
        select(-max_id)
      dbDisconnect(con)
      data
    })


      con <- simulation_db()
      tree <- discussionTree()
      data <- dbGetQuery(con, "SELECT * FROM effect") %>%
        data.frame() %>%
        filter(post_id %in% tree$post_id | note_id %in% tree$post_id) %>%
        mutate(magnitude = relative_entropy(p, q))
      dbDisconnect(con)
      data
    })

    output$algoVisualization <- renderD3({
      period <- input$period

      discussion_tree <- discussionTree() %>%
        rename(
          parentId = parent_id,
          postId = post_id,
          content = content,
          createdAt = created_at,
          voteEventId = vote_event_id,
          voteEventTime = vote_event_time,
          topNoteId = top_note_id,
          o = o,
          oCount = o_count,
          oSize = o_size,
          p = p,
          score = score,
        )

      effects <- effects() %>%
        rename(
          voteEventId = vote_event_id,
          voteEventTime = vote_event_time,
          tagId = tag_id,
          postId = post_id,
          noteId = note_id,
          p = p,
          q = q,
          r = r,
          pCount = p_count,
          qCount = q_count,
          rCount = r_count,
          pSize = p_size,
          qSize = q_size,
          rSize = r_size,
        )

      discussion_tree_json <- data_to_json(discussion_tree)
      effect_events_json <- data_to_json(effect_events)
      score_events_json <- data_to_json(score_events)
      vote_events_json <- data_to_json(vote_events)
      effects_json <- data_to_json(effects)

      r2d3(
        data = list(
          effects = effects_json,
          period = period,
          discussion_tree = discussion_tree_json,
          effect_events = effect_events_json,
          score_events = score_events_json,
          vote_events = vote_events_json
        ),
        script = "algorithm-visualization.js"
      )
    })
  })
}
