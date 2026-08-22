#   * Entropía teórica:  bits = longitud * log2(charset_size)
#   * Entropía ajustada: bits_teoricos - penalizacion_por_patrones
#     (la penalización está definida en patterns.R)
#   * Trabajo SIEMPRE en escala logarítmica (log2 bits / log10 segundos) para
#     evitar overflow con contraseñas largas (charset^longitud no se calcula).
#   * Velocidad de ataque default: 10^10 intentos/segundo.

# Conjunto exacto de 32 símbolos comunes (26 del prompt + 6 complementarios:
# ~ ` / \ " '). Orden y tamaño quedan fijados acá a propósito.
.SIMBOLOS_COMUNES <- "!@#$%^&*()_+-=[]{}|;:,.<>?~`/\\\"'"

.TAM_MINUSCULAS <- 26L
.TAM_MAYUSCULAS <- 26L
.TAM_NUMEROS    <- 10L
.TAM_SIMBOLOS   <- 32L

#Velocidad de ataque asumida (intentos por segundo).
#Justificación del default (10^10/s): ataque offline con GPU moderna sobre
#hashes rápidos (ej. NTLM/MD5) — Hashcat benchmark documentado en ~10^10
#hashes/s con un rig de varias RTX 4090 (ej. hashes.org / hashcat.net wiki)
VELOCIDAD_DEFAULT <- 1e10

VELOCIDADES_ATAQUE <- list(
  online = 1e3,      #ataque online con rate-limit
  gpu    = 1e10,     #ataque offline con GPU moderna
  cluster = 1e13     #cluster / cloud cracking masivo
)

#Tope de bits para contraseñas que son esencialmente una palabra del
#diccionario embebido (top ~200 términos): log2(200) ≈ 7.64 → 8 bits.
.LIMITE_BITS_DICCIONARIO <- 8

#Charset
calcular_charset <- function(password) {
  pw <- as.character(password %||% "")
  chars <- strsplit(pw, "", fixed = TRUE)[[1]]
  simb <- strsplit(.SIMBOLOS_COMUNES, "", fixed = TRUE)[[1]]

  categorias <- c(
    minusculas = sum(chars %in% letters),
    mayusculas = sum(chars %in% LETTERS),
    numeros    = sum(chars %in% as.character(0:9)),
    simbolos   = sum(chars %in% simb),
    unicode    = sum(!(chars %in% c(letters, LETTERS, as.character(0:9), simb)))
  )

  charset_size <- 0L
  if (categorias[["minusculas"]] > 0L) charset_size <- charset_size + .TAM_MINUSCULAS
  if (categorias[["mayusculas"]] > 0L) charset_size <- charset_size + .TAM_MAYUSCULAS
  if (categorias[["numeros"]]    > 0L) charset_size <- charset_size + .TAM_NUMEROS
  if (categorias[["simbolos"]]   > 0L) charset_size <- charset_size + .TAM_SIMBOLOS

  list(
    longitud       = length(chars),
    charset_size   = charset_size,
    categorias     = categorias,
    unicode_present = categorias[["unicode"]] > 0L,
    unicode_count  = categorias[["unicode"]]
  )
}


calcular_entropia <- function(password) {
  cs <- calcular_charset(password)
  if (cs$longitud == 0L) {
    return(list(
      longitud = 0L, charset_size = 0L,
      entropia_teorica_bits = 0,
      entropia_ajustada_bits = 0,
      bits_penalizados = 0,
      patrones = list(patrones_encontrados = FALSE),
      nota = "contraseña vacía"
    ))
  }

  if (cs$charset_size == 0L) {
    return(list(
      longitud = cs$longitud, charset_size = 0L,
      entropia_teorica_bits = NA_real_,
      entropia_ajustada_bits = NA_real_,
      bits_penalizados = NA_real_,
      patrones = list(patrones_encontrados = FALSE),
      nota = "solo caracteres Unicode: no se estima sin asumir un espacio de caracteres"
    ))
  }

  bits_teoricos <- cs$longitud * log2(cs$charset_size)
  patrones <- detectar_patrones(password, charset_size = cs$charset_size)

  bits_efectivos <- max(bits_teoricos - patrones$penalizacion_bits, 0)

  #Cobertura del diccionario: si la palabra cubre >= 50% de la contraseña
  if (patrones$cobertura_diccionario >= 0.5) {
    bits_efectivos <- min(bits_efectivos, .LIMITE_BITS_DICCIONARIO)
  }

  nota <- if (cs$unicode_present) {
    "cálculo conservador: los caracteres Unicode suman longitud pero no charset asumido"
  } else {
    NULL
  }

  list(
    longitud = cs$longitud,
    charset_size = cs$charset_size,
    entropia_teorica_bits = bits_teoricos,
    entropia_ajustada_bits = bits_efectivos,
    bits_penalizados = patrones$penalizacion_bits,
    patrones = patrones,
    nota = nota
  )
}

#Convierte entropía (bits) a tiempo de crackeo en segundos.

tiempo_estimado <- function(entropia, velocidad = VELOCIDAD_DEFAULT) {
  bits <- if (is.list(entropia)) entropia$entropia_ajustada_bits else entropia
  if (is.na(bits)) {
    return(list(segundos = NA_real_, log10_segundos = NA_real_,
                bits = NA_real_, velocidad = velocidad, calculable = FALSE))
  }
  bits <- max(bits, 0)
  log10_seg <- bits * log10(2) - log10(velocidad)
  seg <- if (log10_seg > 308) Inf else 10^log10_seg
  list(segundos = seg, log10_segundos = log10_seg,
       bits = bits, velocidad = velocidad, calculable = TRUE)
}

#Formatea segundos (o log10 de segundos) a una unidad legible en español.
formatear_tiempo <- function(segundos, log10_segundos = NULL) {
  if (!is.null(log10_segundos) && !is.na(log10_segundos)) {
    log10_t <- log10_segundos
  } else if (!is.na(segundos) && is.finite(segundos) && segundos >= 0) {
    log10_t <- log10(segundos)
  } else if (is.na(segundos)) {
    return("no calculable")
  } else {
    return("más que la edad del universo")
  }

  .SEC <- 0
  .MIN <- log10(60)
  .HOR <- log10(3600)
  .DIA <- log10(86400)
  .ANY <- log10(31557600)          # 1 año = 365.25 días o año juliano
  .MIL <- log10(3.15576e10)        # 1000 años
  .MILL <- log10(3.15576e13)       # 1 millón de años
  .MMIL <- log10(3.15576e16)       # 1000 millones de años
  .UNIV <- log10(4.354e17)         # edad del universo

  unidad <- "instantáneo"
  valor <- NULL
  if (log10_t < .SEC) {
    unidad <- "instantáneo"
  } else if (log10_t < .MIN) {
    unidad <- "segundos";  valor <- 10^log10_t
  } else if (log10_t < .HOR) {
    unidad <- "minutos";   valor <- 10^log10_t / 60
  } else if (log10_t < .DIA) {
    unidad <- "horas";     valor <- 10^log10_t / 3600
  } else if (log10_t < .ANY) {
    unidad <- "días";      valor <- 10^log10_t / 86400
  } else if (log10_t < .MIL) {
    unidad <- "años";      valor <- 10^log10_t / 31557600
  } else if (log10_t < .MILL) {
    unidad <- "mil años";  valor <- 10^log10_t / 3.15576e10
  } else if (log10_t < .MMIL) {
    unidad <- "millones de años"; valor <- 10^log10_t / 3.15576e13
  } else if (log10_t < .UNIV) {
    unidad <- "mil millones de años"; valor <- 10^log10_t / 3.15576e16
  } else {
    unidad <- "más que la edad del universo"
  }

  if (unidad == "instantáneo") return("instantáneo")
  if (unidad == "más que la edad del universo") return("más que la edad del universo")

  valor <- round(valor, 6)

  n <- .numero_es(if (unidad %in% c("mil años")) round(valor) else valor)
  singulares <- c(segundos = "segundo", minutos = "minuto", horas = "hora",
                  días = "día", años = "año", `mil años` = "mil años",
                  `millones de años` = "millón de años",
                  `mil millones de años` = "mil millones de años")
  nombre <- singulares[[unidad]]
  plural <- isTRUE(valor > 1 || valor != round(valor))
  if (plural) {
    if (unidad == "segundos")  nombre <- "segundos"
    if (unidad == "minutos")   nombre <- "minutos"
    if (unidad == "horas")     nombre <- "horas"
    if (unidad == "días")      nombre <- "días"
    if (unidad == "años")      nombre <- "años"
    if (unidad == "mil años")  nombre <- "mil años"
    if (unidad == "millones de años")      nombre <- "millones de años"
    if (unidad == "mil millones de años")  nombre <- "mil millones de años"
  }
  paste(n, nombre)
}

#Redondeo bonito: 2 cifras significativas, coma decimal, punto de miles.
.numero_es <- function(x) {
  r <- signif(x, 2)
  if (r >= 100) return(formatC(round(r), format = "d", big.mark = ".", decimal.mark = ","))
  if (r == round(r)) return(formatC(r, format = "d", big.mark = ".", decimal.mark = ","))
  dec <- if (r >= 10) 1 else 1
  sub("\\.", ",", formatC(r, format = "f", digits = dec, decimal.mark = ","))
}

`%||%` <- function(a, b) {
  if (is.null(a)) return(b)
  if (!is.atomic(a)) return(a)
  if (length(a) == 0L) return(b)
  if (is.na(a)) return(b)
  a
}