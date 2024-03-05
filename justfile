julia:
    julia --project

agents:
    julia --project scripts/model.jl

sqlite:
    sqlite3 $DATABASE_PATH

# shiny:
#     Rscript -e "shiny::runApp('app', port = 3456)"

shiny:
  find app | entr -cnr bash -c "Rscript -e \"shiny::runApp('app', port = 3456)\""

personas:
    julia --project scripts/personas.jl

test:
    julia --project scripts/voting-tests.jl

wq:
    sqlite3 $DATA_PATH/social-network.db < sql/working-query.sql

develop:
  process-compose -f process-compose.yaml --tui=false up



up-code-stats:
    date > notes/abm-stats.md
    echo \`\`\` >> notes/abm-stats.md
    cloc src >> notes/abm-stats.md
    echo \`\`\` >> notes/abm-stats.md
    date > notes/shiny-app-stats.md
    echo \`\`\` >> notes/shiny-app-stats.md
    cloc app >> notes/shiny-app-stats.md
    echo \`\`\` >> notes/shiny-app-stats.md
