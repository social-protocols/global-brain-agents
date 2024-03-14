julia:
    julia --project

# ------------------------------------------
# --- GPT ABM ------------------------------
# ------------------------------------------

agents:
    julia --project scripts/model.jl

agents-app:
    Rscript -e \"shiny::runApp('gpt-agents-app', port = 3456)\

personas:
    julia --project scripts/personas.jl

sqlite:
    litecli $DATABASE_PATH

# ------------------------------------------
# --- Prototype and Simulations ------------
# ------------------------------------------

shiny:
    find app | entr -cnr bash -c "Rscript -e \"shiny::runApp('app', port = 3456)\""

# -- Doesn't work, but keep for reference
# develop:
#   process-compose -f process-compose.yaml --tui=false up

# ------------------------------------------
# --- Code Stats ---------------------------
# ------------------------------------------

up-code-stats:
    date > notes/abm-stats.md
    echo \`\`\` >> notes/abm-stats.md
    cloc src >> notes/abm-stats.md
    echo \`\`\` >> notes/abm-stats.md
    date > notes/shiny-app-stats.md
    echo \`\`\` >> notes/shiny-app-stats.md
    cloc app >> notes/shiny-app-stats.md
    echo \`\`\` >> notes/shiny-app-stats.md
