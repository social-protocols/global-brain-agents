julia:
    julia --project

agents:
    julia --project scripts/model.jl

sqlite:
    sqlite3 $DATABASE_PATH

shiny:
    Rscript -e "shiny::runApp('app', port = 3456)"

personas:
    julia --project scripts/personas.jl
