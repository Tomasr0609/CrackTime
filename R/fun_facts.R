#Tabla de hechos curiosos: cada fila es el límite SUPERIOR de log10(segundos)

.FUN_FACTS <- list(
  list(hasta = -3.00,   texto = "más rápido que un parpadeo — ni te vas a dar cuenta",
                        icono = "fa-bolt"),
  list(hasta = 0.00,    texto = "en menos de lo que tardás en leer esta frase",
                        icono = "fa-comment"),
  list(hasta = 2.477,   texto = "mientras preparás un mate",
                        icono = "fa-mug-hot"),
  list(hasta = 3.556,   texto = "lo que tarda en hervir un huevo",
                        icono = "fa-egg"),
  list(hasta = 4.936,   texto = "un episodio de tu serie favorita",
                        icono = "fa-tv"),
  list(hasta = 5.782,   texto = "un maratón completo... y varias ediciones más",
                        icono = "fa-person-running"),
  list(hasta = 6.420,   texto = "una semana de vacaciones",
                        icono = "fa-umbrella-beach"),
  list(hasta = 7.499,   texto = "un mes de alquiler",
                        icono = "fa-house"),
  list(hasta = 8.499,   texto = "un ciclo escolar completo",
                        icono = "fa-graduation-cap"),
  list(hasta = 9.499,   texto = "una década entera",
                        icono = "fa-calendar-days"),
  list(hasta = 10.499,  texto = "más que una vida humana promedio",
                        icono = "fa-heart-pulse"),
  list(hasta = 11.499,  texto = "toda la Edad Media",
                        icono = "fa-landmark"),
  list(hasta = 12.499,  texto = "la última era de hielo",
                        icono = "fa-snowflake"),
  list(hasta = 13.499,  texto = "toda la historia de la humanidad moderna (~300.000 años)",
                        icono = "fa-user-astronaut"),
  list(hasta = 15.499,  texto = "los dinosaurios se extinguieron hace 66 millones de años",
                        icono = "fa-bone"),
  list(hasta = 16.499,  texto = "la historia de la Tierra multiplicada por varias veces",
                        icono = "fa-earth-americas"),
  list(hasta = 17.639,  texto = "más que toda la edad de la Tierra (4.500 millones de años)",
                        icono = "fa-earth-africa"),
  list(hasta = Inf,     texto = "más que la edad del universo",
                        icono = "fa-infinity")
)

dato_curioso <- function(tiempo) {
  log10_t <- if (is.list(tiempo)) tiempo$log10_segundos else log10(max(tiempo, 1e-320))
  if (is.na(log10_t)) {
    return(list(texto = "Con caracteres Unicode no se puede estimar sin asumir un espacio: la respuesta honesta es que no sabemos.",
                icono = "fa-circle-question", escala = "no_calculable"))
  }
  for (f in .FUN_FACTS) {
    if (log10_t < f$hasta) {
      return(list(texto = f$texto, icono = f$icono,
                  escala = .escala(log10_t)))
    }
  }
  list(texto = "más que la edad del universo", icono = "fa-infinity",
       escala = "universo")
}

.escala <- function(log10_t) {
  if (log10_t < 4.936) return("instantaneo")
  if (log10_t < 7.499) return("dias")
  if (log10_t < 9.499) return("vida")
  if (log10_t < 13.499) return("historico")
  if (log10_t < 17.639) return("geologico")
  return("universo")
}