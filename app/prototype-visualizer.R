library(DBI)
library(dplyr)
library(tidyr)
library(shiny)
library(DiagrammeR)
library(ggplot2)

PROTOTYPE_DATABASE_PATH <- Sys.getenv("PROTOTYPE_DATABASE_PATH")

prototypeVisualizerUI <- function(id) {
  fluidPage(
    h1("Prototype Visualizer"),
    fluidRow(
      box(
        fluidRow(
          column(width = 2,
            numericInput(
              NS(id, "tagId"), "Tag ID",
              min = 1, max = 100, step = 1, value = 1,
              width = "100%"
            ),
          ),
          column(width = 2,
            numericInput(
              NS(id, "postId"), "Post ID",
              min = 1, max = 100, step = 1, value = 1,
              width = "100%"
            )
          ),
        ),
      ),
    ),
    fluidRow(
      tabsetPanel(id = "interactive-visualization-tabs",
        tabPanel("Table", dataTableOutput(NS(id, "discussionTreeTable"))),
        tabPanel("Tree", grVizOutput(NS(id, "discussionTreeGraph"))),
        tabPanel("Score", plotOutput(NS(id, "scorePlot")))
      ),
    ),
    fluidRow(
      actionButton(NS(id, "update"), "Update", icon = icon("refresh")),
    )
  )
}

prototypeVisualizerServer <- function(id) {
  moduleServer(id, function(input, output, session) {
    prototype_db <- function() {
      dbConnect(RSQLite::SQLite(), PROTOTYPE_DATABASE_PATH)
    }

    scoreDataTree <- reactive({
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

    posts <- reactive({
      input$update
      input$tagId
      input$postId
      con <- prototype_db()
      data <- dbGetQuery(con, "SELECT * FROM Post") %>% data.frame()
      dbDisconnect(con)
      data
    })

    scoreEvents <- reactive({
      input$update
      input$tagId
      input$postId
      con <- prototype_db()
      data <- dbGetQuery(con, "SELECT * FROM ScoreEvent") %>% data.frame()
      dbDisconnect(con)
      data
    })

    output$discussionTreeTable <- renderDataTable({
      scoreDataTree() %>%
        select(
          tagId,
          parentId, postId, topNoteId,
          p, q, overallP,
          count, sampleSize,
          score
        ) %>%
        left_join(
          posts() %>% select(id, content),
          by = c("postId" = "id")
        ) %>%
        mutate(
          p = round(p, 2),
          q = round(q, 2),
          overallP = round(overallP, 2),
          score = round(score, 2)
        ) %>%
        rename(
          informedP = p,
          uninformedP = q,
          upvotes = count,
          totalVotes = sampleSize
        ) %>%
        relocate(parentId, postId, topNoteId, content)
    })

    output$discussionTreeGraph <- renderGrViz({
      tag_id <- input$tagId
      score_data <- scoreDataTree()
      net <- note_effect_graph(score_data)
      render_graph(net, layout = "tree")
    })

    output$scorePlot <- renderPlot({
      scoreEvents() %>%
        filter(tagId == input$tagId, postId == input$postId) %>%
        select(voteEventTime, score) %>%
        ggplot(aes(x = voteEventTime, y = score)) +
        scale_y_continuous(limits = c(-3, 3)) +
        geom_hline(yintercept = 0, color = "grey", size = 1) +
        geom_line(size = 2, color = "forestgreen") +
        geom_point(shape = 21, size = 6, color = "forestgreen", fill = "white") +
        theme(panel.background = element_rect(fill = "grey95"))
    })

  })
}
