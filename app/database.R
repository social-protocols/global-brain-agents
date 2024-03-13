simulation_db <- function() {
  dbConnect(RSQLite::SQLite(), SIM_DATABASE_PATH)
}

get_simulation_choices <- function() {
  con <- simulation_db()
  simulation_choices <-
    dbGetQuery(
      con,
      "
        SELECT DISTINCT tag_id
        FROM VoteEvent
        ORDER BY tag_id
      "
    ) %>%
    data.frame() %>%
    pull()
  dbDisconnect(con)
  return(simulation_choices)
}

get_score_events <- function() {
  con <- simulation_db()
  data <- dbGetQuery(con, "SELECT * FROM ScoreEvent") %>% data.frame()
  dbDisconnect(con)
  return(data)
}

get_vote_events <- function() {
  con <- simulation_db()
  data <- dbGetQuery(con, "SELECT * FROM VoteEvent") %>% data.frame()
  dbDisconnect(con)
  return(data)
}

get_effect_events <- function() {
  con <- simulation_db()
  data <- dbGetQuery(con, "SELECT * FROM EffectEvent") %>%
    data.frame() %>%
    mutate(magnitude = relative_entropy(p, q))
  dbDisconnect(con)
  return(data)
}

