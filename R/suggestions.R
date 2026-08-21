# =============================================================================
# suggestions.R — Sugerencias accionables (Fase 3)
#
# Cada sugerencia recalculá el tiempo estimado con el cambio propuesto para
# mostrar ANTES -> DESPUÉS con números reales. Máximo 3 sugerencias a la vez,
# ordenadas por criticidad. Funciones puras, testeables desde consola.
# =============================================================================

# Charset completo para generar contraseñas aleatorias de referencia.
.CHARSET_FULL <- c(letters, LETTERS, as.character(0:9),
                   strsplit("!@#$%^&*()_+-=[]{}|;:,.<>?~`/\\\"'", "", fixed = TRUE)[[1]])

# Caracteres "limpios" para sumar longitud sin introducir patrones.
.CHARSET_EXTRA <- c(letters, LETTERS, as.character(0:9))

#' Genera una contraseña aleatoria del largo dado (referencia para comparar).
#' Si `seed` se pasa, el resultado es reproducible (tests).
generar_aleatoria <- function(longitud, incluir_simbolos = TRUE, seed = NULL) {
  if (longitud <= 0L) return("")
  pool <- if (incluir_simbolos) .CHARSET_FULL else .CHARSET_EXTRA
  if (!is.null(seed)) set.seed(seed)
  paste(sample(pool, longitud, replace = TRUE), collapse = "")
}

#' Devuelve la entropía ajustada + tiempo para una contraseña.
.calc <- function(password) {
  ent <- calcular_entropia(password)
  tiempo_estimado(ent)
}

#' Genera hasta 3 sugerencias con antes/después en números reales.
generar_sugerencias <- function(password) {
  if (is.null(password) || is.na(password)) password <- ""
  if (nchar(password) == 0L) return(list())

  ent <- calcular_entropia(password)
  tiempo <- tiempo_estimado(ent)
  if (!tiempo$calculable) return(list())

  patrones <- ent$patrones
  n <- nchar(password)
  cs <- ent$charset_size
  t_actual <- formatear_tiempo(tiempo$segundos, tiempo$log10_segundos)

  sugerencias <- list()

  # Tiempo de una cadena aleatoria del mismo largo (contraste honesto).
  aleatoria <- generar_aleatoria(n, seed = 2024)
  t_alea_ent <- calcular_entropia(aleatoria)
  t_alea_res <- tiempo_estimado(t_alea_ent)
  t_alea <- formatear_tiempo(t_alea_res$segundos, t_alea_res$log10_segundos)

  # 1) Palabra del diccionario
  if (patrones$diccionario_encontrado) {
    palabras <- vapply(patrones$diccionario, `[[`, "", "palabra")
    sugerencias[[length(sugerencias) + 1L]] <- list(
      tipo = "diccionario",
      titulo = "Palabra del diccionario",
      texto = sprintf(
        "«%s» aparece en listas de contraseñas filtradas. Los crackers prueban las top 10.000 en segundos: evitá palabras completas, incluso con números o símbolos pegados.",
        paste(palabras, collapse = "» «")
      ),
      antes = t_actual, despues = t_alea,
      nota = sprintf("una cadena aleatoria del mismo largo tardaría %s", t_alea)
    )
  }

  # 2) Leetspeak
  if (patrones$leetspeak) {
    sugerencias[[length(sugerencias) + 1L]] <- list(
      tipo = "leetspeak",
      titulo = "Leetspeak predecible",
      texto = "Las sustituciones como @ por a o 0 por o son predecibles: los algoritmos de cracking las normalizan automáticamente. No suman tanta seguridad como parece.",
      antes = t_actual, despues = t_alea,
      nota = sprintf("una cadena aleatoria del mismo largo tardaría %s", t_alea)
    )
  }

  # 3) Secuencias de teclado / numéricas / alfabéticas
  secs <- patrones$secuencias
  if (length(secs) > 0L && length(sugerencias) < 3L) {
    textos <- unique(vapply(secs, `[[`, "", "texto"))
    sugerencias[[length(sugerencias) + 1L]] <- list(
      tipo = "secuencia",
      titulo = "Secuencias detectadas",
      texto = sprintf(
        "«%s» es de lo primero que prueba un cracker. Reemplazá secuencias predecibles por combinaciones sin orden.",
        paste(textos, collapse = "» «")
      ),
      antes = t_actual, despues = t_alea,
      nota = sprintf("una cadena aleatoria del mismo largo tardaría %s", t_alea)
    )
  }

  # 4) Repeticiones
  reps <- patrones$repeticiones
  if (length(reps) > 0L && length(sugerencias) < 3L) {
    sugerencias[[length(sugerencias) + 1L]] <- list(
      tipo = "repeticion",
      titulo = "Caracteres repetidos",
      texto = "Repetir el mismo carácter no suma entropía real: «aaaa» se rompe igual que «a». Mejor variar cada carácter.",
      antes = t_actual, despues = t_alea,
      nota = sprintf("una cadena aleatoria del mismo largo tardaría %s", t_alea)
    )
  }

  # 5) Sin símbolos
  if (cs > 0L && !grepl("[^A-Za-z0-9]", password) && length(sugerencias) < 3L) {
    con_simbolo <- paste0(password, "!")
    t_despues <- .calc(con_simbolo)
    factor <- 2^(calcular_entropia(con_simbolo)$entropia_ajustada_bits - ent$entropia_ajustada_bits)
    sugerencias[[length(sugerencias) + 1L]] <- list(
      tipo = "simbolo",
      titulo = "Falta un símbolo",
      texto = sprintf(
        "Agregá un símbolo (ej. «!») y el tiempo de crackeo pasa de %s a %s.",
        t_actual, formatear_tiempo(t_despues$segundos, t_despues$log10_segundos)
      ),
      antes = t_actual,
      despues = formatear_tiempo(t_despues$segundos, t_despues$log10_segundos),
      nota = sprintf("el espacio de búsqueda se multiplica por ×%.0f", factor)
    )
  }

  # 6) Longitud corta
  if (n < 12L && length(sugerencias) < 3L) {
    larga <- paste0(password, "kF7x")
    t_despues <- .calc(larga)
    factor <- 2^(calcular_entropia(larga)$entropia_ajustada_bits - ent$entropia_ajustada_bits)
    sugerencias[[length(sugerencias) + 1L]] <- list(
      tipo = "longitud",
      titulo = "Sumá más caracteres",
      texto = sprintf(
        "Sumá 4 caracteres más y el tiempo de crackeo se multiplica por ~×%.0f (%s actual -> %s).",
        factor, t_actual, formatear_tiempo(t_despues$segundos, t_despues$log10_segundos)
      ),
      antes = t_actual,
      despues = formatear_tiempo(t_despues$segundos, t_despues$log10_segundos),
      nota = sprintf("×%.0f por agregar 4 caracteres", factor)
    )
  }

  # 7) Sin sugerencias críticas: mensaje positivo
  if (length(sugerencias) == 0L) {
    sugerencias[[1L]] <- list(
      tipo = "fuerte",
      titulo = "Contraseña sólida",
      texto = "Está por encima de lo que puede romper un ataque realista con GPU. Cuídala: no la reutilices en otros sitios y usá un gestor de contraseñas.",
      antes = t_actual, despues = t_actual,
      nota = "mantené este nivel en todas tus cuentas"
    )
  }

  sugerencias
}