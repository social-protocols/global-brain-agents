library(shiny)
library(shinydashboard)
library(DBI)
library(igraph)
library(plotwidgets)

source("helpers.R")
source("prototype-visualizer.R")
source("simulation-visualizer.R")

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
      tags$style(HTML(".content-wrapper { background-color: #FFFFFF }"))
    ),
    tabItems(
      tabItem(tabName = "interactive",
        prototypeVisualizerUI("prototypeVisualizer")
      ),
      tabItem(tabName = "simulation",
        simulationVisualizerUI("simulationVisualizer")
      )
    )
  ),
)

server <- function(input, output, session) {
  prototypeVisualizerServer("prototypeVisualizer")
  simulationVisualizerServer("simulationVisualizer")
}

shinyApp(ui, server)
