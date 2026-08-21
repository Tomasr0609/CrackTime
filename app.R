# =============================================================================
# app.R (raíz) — Entrypoint de la app CrackTime
#
# Shiny y shinylive requieren app.R en la raíz del directorio de la app.
# La lógica de UI/server vive en R/app.R (estructura definida en el prompt).
# Correr localmente:  shiny::runApp(".")
# =============================================================================

source("R/app.R")  # define ui() y server()

shiny::shinyApp(ui = ui, server = server)