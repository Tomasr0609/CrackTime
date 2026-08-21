# =============================================================================
# tests/manual_tests_fase3.R — Casos de prueba manuales de la Fase 3
# Ejecutar: Rscript tests/manual_tests_fase3.R
# =============================================================================

source("R/entropy.R")
source("R/patterns.R")
source("R/suggestions.R")
source("R/fun_facts.R")

ok <- 0L; fail <- 0L
check <- function(nombre, cond, detalle = "") {
  if (isTRUE(cond)) { ok <<- ok + 1L; cat(sprintf("  [OK] %s\n", nombre)) }
  else { fail <<- fail + 1L; cat(sprintf("  [FALLA] %s  %s\n", nombre, detalle)) }
}

cat("== Sugerencias: reglas y casos de prueba =================================\n")

verificar <- function(pw, tipo_esperado, desc) {
  s <- generar_sugerencias(pw)
  tipos <- vapply(s, `[[`, "", "tipo")
  cat(sprintf("  «%s» (%s): %s\n", pw, desc,
              paste(tipos, collapse = ", ")))
  check(sprintf("«%s» -> sugerencia tipo %s", pw, tipo_esperado),
        tipo_esperado %in% tipos)
  check(sprintf("«%s» -> máx 3 sugerencias", pw), length(s) <= 3L)
  if (length(s) > 0L) {
    check(sprintf("«%s» -> antes/después presentes", pw),
          all(nzchar(vapply(s, `[[`, "", "antes")) &
              nzchar(vapply(s, `[[`, "", "despues"))))
    check(sprintf("«%s» -> textos no vacíos", pw),
          all(nzchar(vapply(s, `[[`, "", "texto"))))
  }
  invisible(s)
}

verificar("password123", "diccionario", "palabra del diccionario")
verificar("P@ssw0rd", "leetspeak", "leetspeak de password")
verificar("qwerty123", "diccionario", "qwerty es diccionario")
verificar("123456", "secuencia", "secuencia numérica")
verificar("asdfgh", "secuencia", "secuencia de teclado")
verificar("aaa111bbb", "repeticion", "repeticiones")
verificar("abcde123", "simbolo", "sin símbolos")
verificar("hola", "longitud", "corta (<12)")
verificar("Xk3#f9q2!aB5z", "fuerte", "aleatoria fuerte")
s_vacia <- generar_sugerencias("")
check("vacía -> lista vacía", length(s_vacia) == 0L)

# antes/después con números reales (no vacíos) en el caso "simbolo"
s_sim <- generar_sugerencias("abcde123")
cat("  detalle ejemplo (simbolo):", s_sim[[1L]]$texto, "\n")

cat("\n== Fun facts: cobertura sin huecos =======================================\n")

# Barrido de -4 a 18 en log10 segundos (representa todo el rango posible)
textos <- character(0)
escalas <- character(0)
for (l in seq(-4, 18, by = 0.5)) {
  d <- dato_curioso(list(log10_segundos = l))
  textos <- c(textos, d$texto)
  escalas <- c(escalas, d$escala)
  if (is.null(d$texto) || is.na(d$texto)) {
    fail <<- fail + 1L; cat(sprintf("  [FALLA] sin texto en log10=%s\n", l))
  }
}
check("todo el rango devuelve texto", length(textos) == length(seq(-4, 18, by = 0.5)))
check("escalas válidas en todo el rango", all(escalas %in%
      c("instantaneo", "dias", "vida", "historico", "geologico", "universo")))

cat("  ejemplos de comparaciones:\n")
for (l in c(-4, 0, 2, 4, 6, 8, 10, 12, 14, 16, 18)) {
  d <- dato_curioso(list(log10_segundos = l))
  cat(sprintf("    log10=%4.1f (%s) -> %s\n", l, d$escala, d$texto))
}

# Dato curioso desde segundos numéricos
d <- dato_curioso(1)
check("acepta segundos numéricos", nzchar(d$texto))
d <- dato_curioso(NA)
check("NA -> mensaje no calculable", nzchar(d$texto))

# No debe haber comparaciones con palabras sensibles/catastróficas
prohibidas <- c("guerra", "bomba", "asesin", "genocidio", "hambre",
                "pandemia", "nazi", "terror", "tsunami", "terremoto", "atentado")
cat("  chequear términos evitados...\n")
check("sin comparaciones sensibles",
      !any(vapply(prohibidas, function(p) any(grepl(p, textos, ignore.case = TRUE)), logical(1))))

cat("\n=============================================================\n")
cat(sprintf("Resultado: %d OK, %d FALLA\n", ok, fail))
if (fail > 0L) quit(status = 1)