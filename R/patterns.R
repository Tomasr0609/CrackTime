#Detección honesta de lo que hace "fuerte" o "débil" a una contraseña real:
#   1. Secuencias de teclado (qwerty, asdfgh, qazwsx...)
#   2. Secuencias numéricas/alfabéticas (1234, 9876, abcd, zyxw...)
#   3. Repeticiones (aaaa, 1111, ...)
#   4. Palabras de diccionario (top 200 términos ES/EN embebidos)

.DICCIONARIO <- c(
  #inglés
  "password", "123456", "123456789", "12345678", "12345", "qwerty",
  "abc123", "monkey", "dragon", "letmein", "trustno1", "baseball",
  "iloveyou", "master", "sunshine", "ashley", "bailey", "shadow",
  "123123", "654321", "superman", "qazwsx", "michael", "football",
  "jesus", "ninja", "mustang", "welcome", "login", "admin", "princess",
  "abcdef", "whatever", "flower", "hottie", "loveme", "zaq12wsx",
  "peanut", "charlie", "chocolate", "batman", "computer", "summer",
  "nothing", "7777777", "1qaz2wsx", "monkey1", "zaq1zaq1", "dragon1",
  "letmein1", "hello", "secret", "money", "love", "happy", "killer",
  "michelle", "jennifer", "chelsea", "friends", "orange", "purple",
  "password1", "password123", "iloveyou1", "football1", "passw0rd",
  "trustno", "amanda", "melissa", "jordan", "alexis", "samantha",
  "kevin", "brian", "nicole", "andrea", "dallas", "joshua", "nicolas",
  #español
  "contraseña", "clave", "hola", "hola123", "admin123", "teamo",
  "tequiero", "amor", "familia", "perro", "gato", "casa", "trabajo",
  "escuela", "universidad", "gracias", "amigos", "argentina", "mexico",
  "colombia", "chile", "peru", "espana", "venezuela", "brasil", "uruguay",
  "paraguay", "bolivia", "ecuador", "maria", "juan", "jose", "luis",
  "carlos", "pedro", "ana", "sofia", "camila", "valentina", "fernando",
  "alejandro", "andres", "diego", "santiago", "mateo", "sebastian",
  "antonio", "jorge", "miguel", "daniel", "david", "angel", "oscar",
  "hugo", "pablo", "victoria", "lucia", "paula", "luna", "cielo",
  "estrella", "daniela", "gabriela", "isabella", "valeria", "micaela",
  "catalina", "antonella", "sofia123", "mateo123", "bonita", "hermoso",
  "princesa", "reina", "rey", "guerrero", "campeon", "futbol", "futbol123",
  "messi", "ronaldo", "barcelona", "madrid", "river", "boca", "racing",
  "pelota", "gol", "equipo", "musica", "guitarra", "banda", "rock",
  "reggaeton", "cumbia", "tango", "pelicula", "cine", "serie", "netflix",
  "youtube", "google", "facebook", "instagram", "whatsapp", "correo",
  "email", "gmail", "cuenta", "usuario", "miclave", "tigre", "leon",
  "oso", "lobo", "zorro", "caballo", "vaca", "mono", "elefante",
  "jirafa", "cebra", "delfin", "tiburon", "serpiente", "aguila",
  "pato", "gallina", "pollo", "abeja", "mariposa", "uno", "dos",
  "tres", "cuatro", "cinco", "seis", "siete", "ocho", "nueve", "diez",
  "cien", "mil", "one", "two", "three", "four", "five", "six", "seven",
  "eight", "nine", "ten", "lunes", "martes", "miercoles", "jueves",
  "viernes", "sabado", "domingo", "enero", "febrero", "marzo", "abril",
  "mayo", "junio", "julio", "agosto", "septiembre", "octubre",
  "noviembre", "diciembre", "monday", "tuesday", "wednesday", "thursday",
  "friday", "saturday", "sunday", "january", "february", "march",
  "april", "june", "july", "september", "october", "november", "december"
)

#Mapa de normalización: se aplica ANTES de chequear el diccionario
.LEETSPEAK <- c("@" = "a", "4" = "a", "0" = "o", "3" = "e", "1" = "l",
                "!" = "i", "|" = "i", "$" = "s", "5" = "s", "7" = "t",
                "+" = "t", "2" = "z", "9" = "g", "8" = "b")

.FILAS_TECLADO <- c("qwertyuiop", "asdfghjkl", "zxcvbnm")
.PATRONES_TECLADO <- c("qazwsx", "edcrfv", "qwe", "asd", "zxc", "wasd",
                       "qaz", "wsx", "edc", "rfv", "tgb", "yhn", "ujm",
                       "ikol", "qweasdzxc", "poiuytrewq", "lkjhgfdsa",
                       "mnbvcxz")

#Número estimado de secuencias comunes (para la penalización)
.LOG2_N_SECUENCIAS <- log2(100)
#Tamaño del diccionario embebido (para la penalización)
.LOG2_N_DICCIONARIO <- log2(200)


#Tamaño de charset por categoría (fallback local para uso standalone)
.charset_size_local <- function(password) {
  pw <- if (is.null(password) || is.na(password)) "" else as.character(password)
  chars <- strsplit(pw, "", fixed = TRUE)[[1]]
  simb <- strsplit("!@#$%^&*()_+-=[]{}|;:,.<>?~`/\\\"'", "", fixed = TRUE)[[1]]
  size <- 0L
  if (any(chars %in% letters))  size <- size + 26L
  if (any(chars %in% LETTERS))  size <- size + 26L
  if (any(chars %in% as.character(0:9))) size <- size + 10L
  if (any(chars %in% simb))      size <- size + 32L
  size
}

#Normaliza una contraseña para comparación: minúsculas + leetspeak
.normalizar_leetspeak <- function(password) {
  pw <- tolower(password)
  for (k in names(.LEETSPEAK)) {
    pw <- gsub(k, .LEETSPEAK[[k]], pw, fixed = TRUE)
  }
  pw
}

#Runs maximales de un mismo carácter (largo >= 3)
.encontrar_repeticiones <- function(pw) {
  runs <- list()
  n <- nchar(pw)
  i <- 1L
  while (i <= n) {
    ch <- substr(pw, i, i)
    j <- i
    while (j < n && substr(pw, j + 1, j + 1) == ch) j <- j + 1L
    if (j - i + 1L >= 3L) {
      runs[[length(runs) + 1L]] <- list(
        tipo = "repeticion", subtipo = "repeticion",
        inicio = i, fin = j, largo = j - i + 1L,
        texto = substr(pw, i, j), char = ch
      )
    }
    i <- j + 1L
  }
  runs
}

#Runs consecutivos de dígitos (123, 9876) o letras (abc, zyx), ±1
.encontrar_consecutivos <- function(pw, tipo) {
  chars <- strsplit(pw, "", fixed = TRUE)[[1]]
  if (length(chars) < 3L) return(list())
  numeros <- suppressWarnings(as.integer(chars))
  letras <- suppressWarnings(match(chars, letters))
  runs <- list()
  for (d in c(1L, -1L)) {
    i <- 1L
    while (i <= length(chars) - 2L) {
      seq <- if (tipo == "numerica") numeros else letras
      if (!is.na(seq[i]) && !is.na(seq[i + 1L]) && !is.na(seq[i + 2L]) &&
          seq[i + 1L] - seq[i] == d && seq[i + 2L] - seq[i + 1L] == d) {
        j <- i + 2L
        while (j < length(chars) && !is.na(seq[j + 1L]) && seq[j + 1L] - seq[j] == d) {
          j <- j + 1L
        }
        largo <- j - i + 1L
        runs[[length(runs) + 1L]] <- list(
          tipo = "secuencia",
          subtipo = if (tipo == "numerica") "numerica" else "alfabetica",
          inicio = i, fin = j, largo = largo,
          texto = paste(chars[i:j], collapse = "")
        )
        i <- j + 1L
      } else {
        i <- i + 1L
      }
    }
  }
  runs
}

#Runs de teclado (subcadenas de filas, en ambos sentidos, largo >= 3)
.encontrar_teclado <- function(pw) {
  runs <- list()
  .reversa <- function(s) paste(rev(strsplit(s, "", fixed = TRUE)[[1]]), collapse = "")
  for (fila in .FILAS_TECLADO) {
    fila_rev <- .reversa(fila)
    n <- nchar(pw)
    for (i in seq_len(n)) {
      ch <- substr(pw, i, i)
      pos <- gregexpr(ch, fila, fixed = TRUE)[[1]]
      if (pos[1] == -1L) next
      for (p in pos) {
        for (sentido in c(fila, fila_rev)) {
          q <- p; j <- i; largo <- 1L
          repeat {
            if (j + 1L > n || q + 1L > nchar(sentido)) break
            if (substr(pw, j + 1L, j + 1L) != substr(sentido, q + 1L, q + 1L)) break
            j <- j + 1L; q <- q + 1L; largo <- largo + 1L
          }
          if (largo >= 3L) {
            runs[[length(runs) + 1L]] <- list(
              tipo = "secuencia", subtipo = "teclado",
              inicio = i, fin = i + largo - 1L, largo = largo,
              texto = substr(pw, i, i + largo - 1L)
            )
          }
        }
      }
    }
  }
  for (pat in .PATRONES_TECLADO) {
    m <- gregexpr(pat, pw, fixed = TRUE)[[1]]
    if (m[1] != -1L) {
      for (k in seq_along(m)) {
        ini <- as.integer(m[k])
        largo <- attr(m, "match.length")[k]
        runs[[length(runs) + 1L]] <- list(
          tipo = "secuencia", subtipo = "teclado",
          inicio = ini, fin = ini + largo - 1L, largo = largo,
          texto = substr(pw, ini, ini + largo - 1L)
        )
      }
    }
  }
  runs
}

#Palabras del diccionario encontradas como subcadenas (sobre la versión
#normalizada). Devuelve matches (palabra, inicio, fin, largo)
.encontrar_diccionario <- function(pw_norm) {
  matches <- list()
  n <- nchar(pw_norm)
  if (n < 3L) return(matches)
  for (largo in 3L:n) {
    if (largo > n) next
    for (i in seq_len(n - largo + 1L)) {
      sub <- substr(pw_norm, i, i + largo - 1L)
      if (sub %in% .DICCIONARIO) {
        matches[[length(matches) + 1L]] <- list(
          palabra = sub, inicio = i, fin = i + largo - 1L, largo = largo
        )
      }
    }
  }
  matches
}

#Detecta patrones débiles y devuelve la penalización en bits.

detectar_patrones <- function(password, charset_size = NULL) {
  pw_raw <- if (is.null(password) || is.na(password)) "" else as.character(password)
  if (nchar(pw_raw) == 0L) {
    return(list(patrones_encontrados = FALSE, penalizacion_bits = 0,
                repeticiones = list(), secuencias = list(),
                diccionario = list(), diccionario_encontrado = FALSE,
                leetspeak = FALSE, cobertura_diccionario = 0,
                detalle = character(0)))
  }
  if (is.null(charset_size)) charset_size <- .charset_size_local(pw_raw)
  log2c <- if (charset_size > 1) log2(charset_size) else 0
  n <- nchar(pw_raw)
  pw_low <- tolower(pw_raw)
  pw_norm <- .normalizar_leetspeak(pw_raw)

  reps <- .encontrar_repeticiones(pw_low)
  seqs_num <- .encontrar_consecutivos(pw_low, "numerica")
  seqs_alf <- .encontrar_consecutivos(pw_low, "alfabetica")
  seqs_teclado <- .encontrar_teclado(pw_low)
  secuencias <- c(seqs_num, seqs_alf, seqs_teclado)

  dict_matches <- .encontrar_diccionario(pw_norm)

  #Greedy por largo: quedarse con los matches de diccionario que no se solapan
  dict_keep <- list()
  if (length(dict_matches) > 0L) {
    dict_matches <- dict_matches[order(sapply(dict_matches, `[[`, "largo"), decreasing = TRUE)]
    covered_dict <- rep(FALSE, n)
    for (m in dict_matches) {
      rango <- m$inicio:m$fin
      if (any(covered_dict[rango])) next
      dict_keep[[length(dict_keep) + 1L]] <- m
      covered_dict[rango] <- TRUE
    }
  } else {
    covered_dict <- rep(FALSE, n)
  }

  if (length(dict_keep) > 0L) {
    letras_leet <- names(.LEETSPEAK)
    leetspeak <- any(vapply(dict_keep, function(m) {
      rango <- m$inicio:m$fin
      sub_pw <- substr(pw_raw, m$inicio, m$fin)
      any(strsplit(sub_pw, "", fixed = TRUE)[[1]] %in% letras_leet)
    }, logical(1)))
  } else {
    leetspeak <- FALSE
  }

  penalizacion <- 0
  covered <- rep(FALSE, n)
  detalle <- character(0)

  #1) Diccionario
  for (m in dict_keep) {
    rango <- m$inicio:m$fin
    if (any(covered[rango])) next
    seg_pen <- m$largo * log2c - .LOG2_N_DICCIONARIO
    if (seg_pen > 0) {
      penalizacion <- penalizacion + seg_pen
      covered[rango] <- TRUE
    }
    detalle <- c(detalle, sprintf("diccionario: «%s»", m$palabra))
  }

  #2) Repeticiones
  for (r in reps) {
    rango <- r$inicio:r$fin
    if (any(covered[rango])) next
    seg_pen <- (r$largo - 1L) * log2c
    if (seg_pen > 0) {
      penalizacion <- penalizacion + seg_pen
      covered[rango] <- TRUE
    }
    detalle <- c(detalle, sprintf("repetición: «%s» (%d veces)", r$char, r$largo))
  }

  #3) Secuencias
  for (s in secuencias) {
    rango <- s$inicio:s$fin
    if (any(covered[rango])) next
    seg_pen <- s$largo * log2c - .LOG2_N_SECUENCIAS
    if (seg_pen > 0) {
      penalizacion <- penalizacion + seg_pen
      covered[rango] <- TRUE
    }
    detalle <- c(detalle, sprintf("secuencia %s: «%s»", s$subtipo, s$texto))
  }

  #4) Nota de leetspeak (la penalización ya la aplica el diccionario)
  if (leetspeak) {
    detalle <- c(detalle, "sustituciones leetspeak presentes")
  }

  cobertura_dict <- if (n > 0L) sum(covered_dict) / n else 0

  list(
    patrones_encontrados = length(detalle) > 0L,
    penalizacion_bits = penalizacion,
    repeticiones = reps,
    secuencias = secuencias,
    diccionario = dict_keep,
    diccionario_encontrado = length(dict_keep) > 0L,
    leetspeak = leetspeak,
    cobertura_diccionario = cobertura_dict,
    detalle = detalle
  )
}