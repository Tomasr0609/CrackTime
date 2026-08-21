# =============================================================================
# tests/test_app.R — Tests de la app (Fase 4)
# Ejecutar: Rscript tests/test_app.R
#
# Estrategia:
#  1) Lógica pura `calcular_resultado()` probada de forma síncrona con 8
#     contraseñas variadas (evita las limitaciones de testServer con
#     debounce/later).
#  2) Un único testServer verifica que la reactividad conecta bien los outputs
#     (patrón que se comporta estable).
#  3) UI estática: type=password, mensaje de privacidad, toggle mostrar.
# =============================================================================

library(shiny)
source("R/entropy.R"); source("R/patterns.R")
source("R/suggestions.R"); source("R/fun_facts.R"); source("R/app.R")

ok <- 0L; fail <- 0L
check <- function(nombre, cond, detalle = "") {
  if (isTRUE(cond)) { ok <<- ok + 1L; cat(sprintf("  [OK] %s\n", nombre)) }
  else { fail <<- fail + 1L; cat(sprintf("  [FALLA] %s  %s\n", nombre, detalle)) }
}

cat("== 1) Lógica pura calcular_resultado() ====================================\n")

casos <- c("", "a", "123456", "P@ssw0rd", "Xk3#f9q2!aB5z",
           "password123", "hola", "aB3!kL9#xQ2$")

for (pw in casos) {
  r <- calcular_resultado(pw, "gpu")
  if (nchar(pw) == 0L) {
    check("vacía -> NULL", is.null(r))
  } else {
    cat(sprintf("  «%s» -> %s (fortaleza: %s)\n", substr(pw, 1, 12),
                formatear_tiempo(r$tiempo$segundos, r$tiempo$log10_segundos),
                r$fortaleza$texto))
    check(sprintf("«%s»: resultado completo", substr(pw, 1, 8)),
          !is.null(r$entropia) && !is.null(r$tiempo) && !is.null(r$dato) &&
          length(r$sugerencias) > 0L)
    check(sprintf("«%s»: hero formateado", substr(pw, 1, 8)),
          nzchar(formatear_tiempo(r$tiempo$segundos, r$tiempo$log10_segundos)))
  }
}

# Escenario cluster acelera el tiempo
r_gpu <- calcular_resultado("Xk3#f9q2!aB5z", "gpu")
r_clu <- calcular_resultado("Xk3#f9q2!aB5z", "cluster")
cat("  gpu:", formatear_tiempo(r_gpu$tiempo$segundos, r_gpu$tiempo$log10_segundos),
    "| cluster:", formatear_tiempo(r_clu$tiempo$segundos, r_clu$tiempo$log10_segundos), "\n")
check("cluster más rápido que gpu",
      r_clu$tiempo$log10_segundos < r_gpu$tiempo$log10_segundos)

# Fortaleza por umbrales (ajustada)
f <- etiqueta_fortaleza(20);  check("20 bits -> débil",  f$texto == "débil")
f <- etiqueta_fortaleza(45);  check("45 bits -> media",  f$texto == "media")
f <- etiqueta_fortaleza(70);  check("70 bits -> fuerte", f$texto == "fuerte")
f <- etiqueta_fortaleza(90);  check("90 bits -> muy fuerte", f$texto == "muy fuerte")

cat("\n== 2) Reactividad del server (testServer) ================================\n")

# Un solo testServer: seteo un input y leo un output (patrón estable)
res <- NULL
testServer(server, {
  session$setInputs(password = "123456", escenario = "gpu")
  session$flushReact()
  Sys.sleep(0.4)
  later::run_now()
  session$flushReact()
  res <<- list(hero = output$tiempo_hero, nota = output$tiempo_nota)
})
cat("  hero:", res$hero, "\n")
check("server: hero no es '…'", res$hero != "…" && nzchar(res$hero))
check("server: nota menciona caracteres", grepl("caracteres", res$nota))

# Regresión debounce: dos cambios seguidos (el 2º ejecuta la cancelación del
# timer anterior). Con `$destroy()` (bug Fase 6) el 2º cambio explotaba.
res2 <- NULL
testServer(server, {
  session$setInputs(password = "123456", escenario = "gpu")
  session$flushReact(); Sys.sleep(0.4); later::run_now(); session$flushReact()
  res2 <<- list(hero1 = output$tiempo_hero)
  session$setInputs(password = "Xk3#f9q2!aB5z")
  session$flushReact(); Sys.sleep(0.4); later::run_now(); session$flushReact()
  res2$hero2 <<- output$tiempo_hero
})
cat("  debounce: 1º =", res2$hero1, "| 2º =", res2$hero2, "\n")
check("debounce: el 2º cambio actualiza el hero",
      nzchar(res2$hero1) && nzchar(res2$hero2) && res2$hero1 != res2$hero2)

cat("\n== 3) UI estática =========================================================\n")

u <- paste(as.character(ui()), collapse = "")
check("password input con type=password", grepl("type=.password.", u))
check("mensaje de privacidad en UI", grepl("nunca se env", u))
check("toggle mostrar presente", grepl("mostrar", u))
check("campo de escenario presente", grepl("escenario", u))
check("sección compartir presente", grepl("compartir", u))

cat("\n=============================================================\n")
cat(sprintf("Resultado: %d OK, %d FALLA\n", ok, fail))
if (fail > 0L) quit(status = 1)