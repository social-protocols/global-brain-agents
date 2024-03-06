library(r2d3)
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
          column(width = 4,
            numericInput(
              NS(id, "tagId"), "Tag ID",
              min = 1, max = 100, step = 1, value = 1,
              width = "100%"
            ),
          ),
          column(width = 4,
            numericInput(
              NS(id, "postId"), "Post ID",
              min = 1, max = 100, step = 1, value = 1,
              width = "100%"
            )
          ),
          column(width = 4,
            checkboxInput(
              NS(id, "showPostText"), "Show Post Text",
              value = TRUE
            )
          ),
        ),
      ),
    ),
    fluidRow(
      tabsetPanel(id = "interactive-visualization-tabs",
        tabPanel("D3", d3Output(NS(id, "d3"))),
        tabPanel("Tree", grVizOutput(NS(id, "discussionTreeGraph"))),
        tabPanel("Table", dataTableOutput(NS(id, "discussionTreeTable"))),
        tabPanel("Score", plotOutput(NS(id, "scorePlot")))
      ),
    ),
  )
}

prototypeVisualizerServer <- function(id) {
  moduleServer(id, function(input, output, session) {
    prototype_db <- function() {
      dbConnect(RSQLite::SQLite(), PROTOTYPE_DATABASE_PATH)
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
      }
    )

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
        relocate(parentId, postId, topNoteId, content) %>%
        rename(
          Parent = parentId,
          Post = postId,
          `Top Note` = topNoteId,
          Content = content,
          Informed = p,
          Uninformed = q,
          Overall = overallP,
          Upvotes = count,
          `Total Votes` = sampleSize,
          Score = score
        )
    })

    output$discussionTreeGraph <- renderGrViz({
      tag_id <- input$tagId
      post_id <- input$postId
      show_content <- input$showPostText
      score_data <- scoreDataTree()
      posts <- posts()
      if (nrow(score_data) > 0) {
        net <- note_effect_graph(score_data, posts, show_content)
      } else {
        net <- create_graph() %>%
          add_node(
            label = "Post does not exist",
            node_aes = node_aes(shape = "plaintext")
          )
      }
      render_graph(net, layout = "tree")
    })

    output$scorePlot <- renderPlot({
      scoreEvents() %>%
        mutate(voteEventTime = as.numeric(voteEventTime)) %>%
        filter(tagId == input$tagId, postId == input$postId) %>%
        select(voteEventTime, score) %>%
        ggplot(aes(x = voteEventTime, y = score)) +
        scale_y_continuous(limits = c(-3, 3), breaks = seq(-3, 3, 1)) +
        geom_hline(yintercept = 0, color = "grey20", linewidth = 1) +
        geom_line(linewidth = 2, color = "firebrick") +
        geom_point(
          shape = 21, size = 6,
          color = "firebrick", fill = "white"
        ) +
        labs(x = "Time", y = "Score") +
        theme(
          panel.background = element_rect(fill = "grey95"),
          panel.grid.major = element_line(color = "grey80"),
          panel.grid.minor = element_line(color = "grey80"),
          axis.text.x = element_blank()
        )
    })

    output$d3 <- renderD3({
      posts <- posts() %>% select(id, content)

      score_data <- scoreDataTree() %>%
        mutate(
          effect_on_parent_magnitude = relative_entropy(parentP, parentQ)
        ) %>%
        left_join(posts, by = c("postId" = "id")) %>%
        identity()
      print(score_data)
      r2d3(
        data = score_data,
        script = "bar-chart.js"
      )
    })

  })
}
