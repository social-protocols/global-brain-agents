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
      menuItem("Interactive", tabName = "interactive-demo"),
      menuItem("Simulation", tabName = "simulation-demo")
    )
  ),
  dashboardBody(
    tags$head(
      tags$style(HTML(".content-wrapper { background-color: #FFFFFF }"))
    ),
    tabItems(
      tabItem(tabName = "interactive-demo",
        prototypeVisualizerUI("prototypeVisualizer")
      ),
      tabItem(tabName = "simulation-demo",
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
