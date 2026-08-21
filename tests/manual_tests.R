# =============================================================================
# tests/manual_tests.R — Casos de prueba manuales de la Fase 2
# Ejecutar desde la raíz del proyecto:  Rscript tests/manual_tests.R
# =============================================================================

source("R/entropy.R")
source("R/patterns.R")

resultados <- character(0)
ok <- 0L
fail <- 0L

check <- function(nombre, cond, detalle = "") {
  if (isTRUE(cond)) {
    ok <<- ok + 1L
    cat(sprintf("  [OK] %s\n", nombre))
  } else {
    fail <<- fail + 1L
    cat(sprintf("  [FALLA] %s  %s\n", nombre, detalle))
  }
}

cat("== Test 1: funciones aisladas ============================================\n")

cat("\n-- calcular_charset --\n")
cs <- calcular_charset("Ab1!")
cat("  charset size:", cs$charset_size, "| longitud:", cs$longitud,
    "| categorias:", paste(names(cs$categorias), cs$categorias, sep = "=", collapse = ", "), "\n")
check("charset 'Ab1!' = 94", cs$charset_size == 94L)
check("longitud 'Ab1!' = 4", cs$longitud == 4L)

cat("\n-- detectar_patrones --\n")
dp <- detectar_patrones("123456")
cat("  penalizacion_bits:", dp$penalizacion_bits,
    "| encontrados:", dp$patrones_encontrados,
    "| detalle:", paste(dp$detalle, collapse = "; "), "\n")
check("'123456' detecta secuencia/patrón", dp$patrones_encontrados)

cat("\n-- calcular_entropia --\n")
e <- calcular_entropia("Ab1!Xy9#")
cat("  bits teoricos:", e$entropia_teorica_bits,
    "| bits ajustados:", e$entropia_ajustada_bits,
    "| penalizados:", e$bits_penalizados, "\n")
check("'Ab1!Xy9#' no es Inf/NaN", is.finite(e$entropia_teorica_bits) &&
      is.finite(e$entropia_ajustada_bits))

cat("\n-- tiempo_estimado --\n")
t <- tiempo_estimado(e)
cat("  segundos:", format(t$segundos, scientific = TRUE),
    "| log10:", t$log10_segundos, "\n")
check("tiempo calculable", t$calculable)

cat("\n-- formatear_tiempo --\n")
casos_tiempo <- list(
  "0.0001"  = 1e-4, "0.9" = 0.9, "1" = 1, "30" = 30, "90" = 90,
  "3600" = 3600, "2h" = 7200, "1d" = 86400, "30d" = 2592000,
  "1y" = 31557600, "10y" = 3.15576e8, "100y" = 3.15576e9,
  "5k" = 1.57788e11, "2M" = 6.31152e13, "50M" = 1.57788e15,
  "1MM" = 3.15576e16, "100MM" = 3.15576e18
)
for (nm in names(casos_tiempo)) {
  cat(sprintf("  %-8s -> %s\n", nm, formatear_tiempo(casos_tiempo[[nm]])))
}

cat("\n== Test 2: casos documentados ============================================\n")

casos <- list(
  "vacía"              = "",
  "1 carácter"         = "a",
  "patrón obvio"       = "123456",
  "leetspeak"          = "P@ssw0rd",
  "dicc+num"           = "password123",
  "dicc+leet+num"      = "P@ssw0rd1!",
  "secuencia teclado"  = "qwerty123",
  "repetición"         = "aaa111bbb",
  "aleatoria fuerte"   = "Xk3#f9q2!aB5z",
  "muy larga (60)"     = paste(sample(c(letters, LETTERS, 0:9), 60, replace = TRUE), collapse = "")
)

for (nm in names(casos)) {
  pw <- casos[[nm]]
  e <- calcular_entropia(pw)
  t <- tiempo_estimado(e)
  cat(sprintf("  %-22s len=%-3d charset=%-3d teórica=%-8.2f ajustada=%-8.2f tiempo=%s\n",
              paste0("«", nm, "»"), e$longitud, e$charset_size,
              e$entropia_teorica_bits, e$entropia_ajustada_bits,
              formatear_tiempo(t$segundos, t$log10_segundos)))
  check(paste0("no Inf/NaN en «", nm, "»"),
        !any(is.nan(c(e$entropia_teorica_bits, e$entropia_ajustada_bits, t$log10_segundos))) &&
        !is.infinite(t$segundos) || (e$entropia_ajustada_bits > 1024))
}

cat("\n== Verificación de casos específicos ======================================\n")

# 123456 debe ser débil (ajustada << teórica y ~ instantáneo)
e <- calcular_entropia("123456")
t <- tiempo_estimado(e)
check("'123456' ajustada << teórica", e$entropia_ajustada_bits < e$entropia_teorica_bits / 2)
check("'123456' → instantáneo", t$segundos < 60)

# P@ssw0rd (leetspeak de 'password') debe ser débil
e <- calcular_entropia("P@ssw0rd")
check("'P@ssw0rd' detecta diccionario (leetspeak)", e$patrones$diccionario_encontrado)
check("'P@ssw0rd' ajustada < teórica", e$entropia_ajustada_bits < e$entropia_teorica_bits)

# Contraseña aleatoria fuerte: ajustada alta y tiempo enorme
e <- calcular_entropia("Xk3#f9q2!aB5z")
t <- tiempo_estimado(e)
cat(sprintf("  'Xk3#f9q2!aB5z' bits ajustados = %.2f -> %s\n",
            e$entropia_ajustada_bits, formatear_tiempo(t$segundos, t$log10_segundos)))
check("fuerte aleatoria: bits ajustados > 60", e$entropia_ajustada_bits > 60)
check("fuerte aleatoria: no instantáneo", t$segundos > 3.15576e9)

# Contraseña de 60 chars: sin overflow
e <- calcular_entropia(casos[["muy larga (60)"]])
t <- tiempo_estimado(e)
cat(sprintf("  60 chars: log10_segundos = %s\n", format(t$log10_segundos, scientific = TRUE)))
check("60 chars: log10_segundos finito", is.finite(t$log10_segundos))

# vacía: manejo especial
e <- calcular_entropia("")
check("vacía: nota presente", !is.null(e$nota))

# solo unicode: no se asume
e <- calcular_entropia("😀😂")
cat(sprintf("  unicode '😀😂': nota = %s\n", e$nota %||% "-"))
check("solo unicode: ajustada NA (no se asume)", is.na(e$entropia_ajustada_bits))

# símbolos: set exacto de 32
cat("  nchar(.SIMBOLOS_COMUNES) =", nchar(.SIMBOLOS_COMUNES), "\n")
check("set de símbolos = 32", nchar(.SIMBOLOS_COMUNES) == 32L)

cat("\n=============================================================\n")
cat(sprintf("Resultado: %d OK, %d FALLA\n", ok, fail))
if (fail > 0L) quit(status = 1)