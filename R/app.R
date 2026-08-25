#NOTA de estructura: este archivo define `ui()` y `server()`. El archivo
#app.R en la raíz del repo es el entrypoint que los lanza con
#shiny::shinyApp(). Shiny/shinylive exigen app.R (o server.R) en la raíz del
#directorio de la app, así que el código vive acá y el launcher en la raíz.

source("R/entropy.R")
source("R/patterns.R")
source("R/suggestions.R")
source("R/fun_facts.R")

.UMBRAL_DEBIL  <- 35
.UMBRAL_MEDIA  <- 60
.UMBRAL_FUERTE <- 80

etiqueta_fortaleza <- function(bits) {
  if (is.na(bits)) return(list(texto = "no calculable", clase = "fuerza-na",
                               pct = 0, color = "#8b949e"))
  if (bits < .UMBRAL_DEBIL)  return(list(texto = "débil",   clase = "fuerza-debil",
                                         pct = 100 * bits / .UMBRAL_DEBIL,
                                         color = "#ff5d5d"))
  if (bits < .UMBRAL_MEDIA)  return(list(texto = "media",   clase = "fuerza-media",
                                         pct = 100 * bits / .UMBRAL_MEDIA,
                                         color = "#ffb020"))
  if (bits < .UMBRAL_FUERTE) return(list(texto = "fuerte",  clase = "fuerza-fuerte",
                                         pct = 100 * bits / .UMBRAL_FUERTE,
                                         color = "#58d68d"))
  list(texto = "muy fuerte", clase = "fuerza-muyfuerte",
       pct = 100, color = "#00e5a0")
}

.tema <- bslib::bs_theme(
  version = 5,
  bg = "#0b0f14",
  fg = "#e6edf3",
  primary = "#00e5a0",
  secondary = "#8b949e",
  success = "#58d68d",
  info = "#58a6ff",
  warning = "#ffb020",
  danger = "#ff5d5d",
  base_font = bslib::font_collection("Inter", "system-ui", "Segoe UI", "sans-serif"),
  heading_font = bslib::font_collection("Space Grotesk", "Inter", "sans-serif"),
  code_font = bslib::font_collection("JetBrains Mono", "Consolas", "monospace")
)

#UI

ui <- function() {
  bslib::page_fluid(
    theme = .tema,
    lang = "es",
    tags$head(
      tags$link(rel = "icon", type = "image/svg+xml",
                href = "assets/favicon.svg"),
      tags$link(rel = "stylesheet", href = "styles.css"),
      tags$script(HTML(
        "document.addEventListener('DOMContentLoaded', function() {
           var cb = document.getElementById('mostrar');
           var el = document.getElementById('password');
           if (cb && el) {
             cb.addEventListener('change', function() {
               // Toggle 100% client-side (visual puro): basado en cb.checked,
               // sin depender del estado .type (el binding de Shiny lo deja
               // desincronizado entre propiedad y atributo).
               var n = cb.checked ? 'text' : 'password';
               el.setAttribute('type', n);
               el.type = n;
             });
           }
         });"
      )),
      tags$script(HTML(
        "Shiny.addCustomMessageHandler('estilo-fortaleza', function(st) {
           var bar = document.getElementById('barra-fortaleza');
           if (bar) {
             bar.style.width = st.width;
             bar.style.background = st.color;
           }
           var cont = document.getElementById('contenedor-fortaleza');
           if (cont) { cont.style.borderColor = st.color; }
         });"
      )),
      tags$script(HTML(
        "Shiny.addCustomMessageHandler('copiar-resumen', function(texto) {
           if (navigator.clipboard && navigator.clipboard.writeText) {
             navigator.clipboard.writeText(texto).then(function() {
               Shiny.setInputValue('copiado', Math.random());
             });
           }
         });"
      ))
    ),
    div(class = "contenedor",
      div(class = "cabecera",
        h1(class = "titulo", "CrackTime"),
        p(class = "subtitulo",
          "¿Cuánto tardaría una computadora en descifrar tu contraseña por fuerza bruta?")
      ),

      div(class = "banner-privacidad",
        icon("lock"),
        span("Tu contraseña nunca se envía a ningún servidor, todo el cálculo
              ocurre en tu navegador de manera local. Es privado de verdad.")),

      div(class = "tarjeta",
        h2(class = "tarjeta-titulo", "Tu contraseña"),
        div(class = "fila-input",
          (function() {
            pw <- passwordInput("password", NULL,
                                placeholder = "Escribí tu contraseña…",
                                width = "100%")

            pw$children[[2]]$attribs[["aria-label"]] <- "Tu contraseña"
            pw
          })(),
          checkboxInput("mostrar", "Mostrar", width = "100%")
        ),
        div(class = "fortaleza",
          div(id = "contenedor-fortaleza", class = "contenedor-fortaleza",
            div(id = "barra-fortaleza", class = "barra-fortaleza"))
        ),
        uiOutput("etiqueta_fortaleza")
      ),

      div(id = "panel-resultado", class = "tarjeta tarjeta-resultado",
        h2(class = "tarjeta-titulo", "Tiempo estimado de hackeo"),
        div(class = "hero-tiempo", textOutput("tiempo_hero", inline = TRUE)),
        div(class = "hero-nota", textOutput("tiempo_nota", inline = TRUE)),

        radioButtons("escenario", "Escenario de ataque",
          choiceNames = c("GPU moderna (offline)", "Ataque online (con límite)",
                          "Cluster / nube masiva"),
          choiceValues = c("gpu", "online", "cluster"),
          selected = "gpu", inline = TRUE),

        div(class = "detalles-tecnicos", htmlOutput("detalles"))
      ),

      div(id = "panel-dato", class = "tarjeta tarjeta-dato",
        div(class = "dato-icono", uiOutput("dato_icono", inline = TRUE)),
        div(class = "dato-cuerpo",
          h2(class = "tarjeta-titulo", "Para que te hagas una idea…"),
          div(class = "dato-texto", textOutput("dato_texto", inline = TRUE)))
      ),

      div(id = "panel-sugerencias", class = "tarjeta",
        h2(class = "tarjeta-titulo", "Cómo mejorarla"),
        uiOutput("sugerencias")
      ),

      div(class = "tarjeta compartir",
        actionButton("compartir", "Copiar resumen para compartir",
                     class = "btn-compartir", icon = icon("share-nodes")),
        div(class = "compartir-nota", textOutput("compartir_nota", inline = TRUE))
      ),

      div(class = "pie",
        p("Estimación para fuerza bruta a 10^10 intentos/segundo (GPU moderna).
           No asume hashes lentos (bcrypt/argon2). Resultado educativo.")
      )
    )
  )
}


calcular_resultado <- function(password, escenario = "gpu") {
  p <- password %||% ""
  if (nchar(p) == 0L) return(NULL)
  velocidad <- VELOCIDADES_ATAQUE[[escenario]]
  ent <- calcular_entropia(p)
  tiempo <- tiempo_estimado(ent, velocidad)
  list(
    password = p,
    entropia = ent,
    tiempo = tiempo,
    fortaleza = etiqueta_fortaleza(ent$entropia_ajustada_bits),
    sugerencias = generar_sugerencias(p),
    dato = dato_curioso(tiempo),
    escenario = escenario
  )
}

#Server

server <- function(input, output, session) {
  observeEvent(input$mostrar, {
    updateCheckboxInput(session, "mostrar",
                        label = if (input$mostrar) "Ocultar" else "Mostrar")
  })

  pw <- reactive({ input$password %||% "" })
  pw_deb <- reactiveVal("")
  .timer_debounce <- NULL
  observeEvent(pw(), {
    if (!is.null(.timer_debounce)) .timer_debounce()  #later() devuelve una función de cancelación
    .timer_debounce <<- later::later(function() {
      isolate(pw_deb(pw()))
    }, 0.2)
  }, ignoreNULL = FALSE)

  resultado <- reactive({
    calcular_resultado(pw_deb(), input$escenario)
  })

  observe({
    r <- resultado()
    session$sendCustomMessage("estilo-fortaleza",
      if (is.null(r)) list(width = "0%", color = "#8b949e")
      else list(width = paste0(min(r$fortaleza$pct, 100), "%"),
                color = r$fortaleza$color))
  })

  output$etiqueta_fortaleza <- renderUI({
    r <- resultado()
    if (is.null(r)) return(div(class = "fuerza-chip fuerza-na",
                               span("Escribí una contraseña")))
    div(class = paste("fuerza-chip", r$fortaleza$clase),
        span(r$fortaleza$texto))
  })

  output$tiempo_hero <- renderText({
    r <- resultado()
    if (is.null(r)) return("…")
    formatear_tiempo(r$tiempo$segundos, r$tiempo$log10_segundos)
  })

  output$tiempo_nota <- renderText({
    r <- resultado()
    if (is.null(r)) return("Escribí una contraseña para estimar el tiempo.")
    sprintf("para una contraseña de %d caracteres, en %s",
            r$entropia$longitud, input$escenario)
  })

  output$detalles <- renderUI({
    r <- resultado()
    if (is.null(r)) return(NULL)
    e <- r$entropia
    if (is.na(e$entropia_ajustada_bits)) {
      return(tags$p(class = "detalle-na", e$nota %||% ""))
    }
    div(class = "detalles-fila",
      span(HTML(sprintf("Entropía teórica: <b>%.1f bits</b>", e$entropia_teorica_bits))),
      span(HTML(sprintf("Entropía ajustada: <b>%.1f bits</b>", e$entropia_ajustada_bits))),
      span(sprintf("Charset: %d", e$charset_size)),
      span(sprintf("Longitud: %d", e$longitud)),
      if (!is.null(e$nota)) span(class = "nota-unicode", e$nota)
    )
  })

  output$dato_texto <- renderText({
    r <- resultado()
    if (is.null(r)) return("")
    r$dato$texto
  })
  outputOptions(output, "dato_texto", suspendWhenHidden = FALSE)

  output$dato_icono <- renderUI({
    r <- resultado()
    if (is.null(r)) return(icon("lightbulb"))  #ícono default sin resultado
    icon(sub("^fa-", "", r$dato$icono))
  })
  outputOptions(output, "dato_icono", suspendWhenHidden = FALSE)

  output$sugerencias <- renderUI({
    r <- resultado()
    if (is.null(r)) return(div(class = "sugerencia-vacia",
                               "Las sugerencias aparecerán acá."))
    lapply(seq_along(r$sugerencias), function(i) {
      s <- r$sugerencias[[i]]
      div(class = paste("sugerencia", "sugerencia-", s$tipo, sep = ""),
        div(class = "sugerencia-num", i),
        div(class = "sugerencia-cuerpo",
          strong(s$titulo),
          p(s$texto),
          div(class = "sugerencia-antes-despues",
            span(class = "badge-antes", s$antes),
            icon("arrow-right"),
            span(class = "badge-despues", s$despues)),
          if (nzchar(s$nota)) div(class = "sugerencia-nota", s$nota))
      )
    })
  })

  observeEvent(input$compartir, {
    r <- resultado()
    if (is.null(r)) return(NULL)
    resumen <- sprintf(
      "CrackTime: mi contraseña tardaría %s en descifrarse (según un ataque por fuerza bruta con GPU, %d caracteres). Dato: %s. ¿Cuánto tarda la tuya? Probalo acá: https://crack-time.vercel.app/",
      formatear_tiempo(r$tiempo$segundos, r$tiempo$log10_segundos),
      r$entropia$longitud, r$dato$texto
    )
    session$sendCustomMessage("copiar-resumen", resumen)
  })
  .timer_nota <- NULL
  observeEvent(input$copiado, {
    if (!is.null(.timer_nota)) .timer_nota()
    output$compartir_nota <- renderText("¡Resumen copiado! Pegalo donde quieras.")
    #El mensaje después de 2 segundos se va.
    .timer_nota <<- later::later(function() {
      output$compartir_nota <- renderText("")
    }, delay = 2)
  })
}