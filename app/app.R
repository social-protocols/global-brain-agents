library(shiny)
library(shinydashboard)
library(DBI)
library(dplyr)

DATABASE_PATH <- file.path("..",Sys.getenv("DATABASE_PATH"))

db <- dbConnect(RSQLite::SQLite(), DATABASE_PATH)

ui <- fluidPage(
    h1("LLM Experiment: Posts"),
    numericInput("post_id", "Post ID", value = 1, min = 1, max = 100),
    tableOutput("complete_thread"),
    hr(),
    tableOutput("all_posts")
)

server <- function(input, output, session) {
    output$all_posts <- renderTable({
        posts <- dbGetQuery(db, "SELECT * FROM posts") %>% data.frame()
        votes <- dbGetQuery(db, "SELECT * FROM votes") %>% data.frame()
        votes_summary <-
            votes %>%
            group_by(post_id) %>%
            summarise(
                upvotes = sum(upvote),
                votes = n(),
                downvotes = votes - upvotes
            ) %>%
            ungroup() %>%
            relocate(post_id, upvotes, downvotes, votes)
        posts %>%
            left_join(votes_summary, by = c("id" = "post_id")) %>%
            arrange(timestamp)
    })

    output$complete_thread <- renderTable({
        post_id <- input$post_id
        post <- dbGetQuery(
            db,
            "SELECT * FROM posts WHERE id = ?",
            params = list(post_id)
        ) %>% data.frame()
        parent_thread <- get_parent_thread(post_id, db)
        votes <- dbGetQuery(db, "SELECT * FROM votes") %>%
            data.frame()
        votes_summary <-
            votes %>%
            group_by(post_id) %>%
            summarise(
                upvotes = sum(upvote),
                votes = n(),
                downvotes = votes - upvotes
            ) %>%
            ungroup() %>%
            relocate(post_id, upvotes, downvotes, votes)
        parent_thread %>%
            inner_join(votes_summary, by = c("id" = "post_id")) %>%
            arrange(timestamp)
    })
}

get_parent_thread <- function(post_id, db) {
    post <- dbGetQuery(
        db,
        "SELECT * FROM posts WHERE id = ?",
        params = list(post_id)
    ) %>% data.frame()
    parent <- dbGetQuery(
        db,
        "SELECT * FROM posts WHERE id = ?",
        params = list(post$parent_id[1])
    ) %>% data.frame()
    if (nrow(parent) == 0) {
        return(post)
    } else {
        parent_id <- parent$id[1]
        return(post %>% rbind(get_parent_thread(parent_id, db)) %>% arrange(id))
    }
}

shinyApp(ui, server)
