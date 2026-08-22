#tools/build-shinylive.R — Compila la app a estático Shinylive (docs/)
fuentes <- c("app.R", "R", "www")
staging <- file.path(tempdir(), "cracktime-staging")
if (dir.exists(staging)) unlink(staging, recursive = TRUE)
dir.create(staging)

for (f in fuentes) {
  if (!dir.exists(f) && !file.exists(f)) stop("No existe: ", f)
  file.copy(f, staging, recursive = TRUE, copy.mode = TRUE)
}

if (dir.exists("docs")) unlink("docs", recursive = TRUE)
t0 <- Sys.time()
shinylive::export(staging, "docs")
dt <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
unlink(staging, recursive = TRUE)


# URL base del sitio en producción. Se puede sobreescribir con la variable
# de entorno SITE_URL antes de correr el build (ej. desde el CI de Vercel).
# Si no está seteada, se usa un placeholder que hay que reemplazar a mano
# después del primer deploy.
site_url <- Sys.getenv("SITE_URL", unset = "https://REEMPLAZAR-DESPUES-DEL-DEPLOY.vercel.app")
site_url <- sub("/+$", "", site_url)  # sin barra final (evita // duplicado)

inject_head <- paste0(
  sprintf('<meta property="og:url" content="%s" />', site_url),
  '<meta name="description" content="CrackTime estima cuánto tardaría una computadora en descifrar tu contraseña por fuerza bruta. 100% en tu navegador." />',
  '<meta property="og:title" content="CrackTime — ¿Cuánto tardaría en descifrar tu contraseña?" />',
  '<meta property="og:description" content="Estima en tiempo real la fuerza de tu contraseña ante un ataque de fuerza bruta. 100% client-side." />',
  '<meta property="og:type" content="website" />',
  sprintf('<meta property="og:image" content="%s/og-image.png" />', site_url),
  '<meta name="twitter:card" content="summary_large_image" />',
  '<meta name="twitter:title" content="CrackTime" />',
  '<meta name="twitter:description" content="¿Cuánto tardaría una computadora en descifrar tu contraseña por fuerza bruta?" />',
  sprintf('<meta name="twitter:image" content="%s/og-image.png" />', site_url),
  '<link rel="icon" type="image/svg+xml" href="./favicon.svg" />',
  '<link rel="preload" href="./shinylive/webr/R.wasm" as="fetch" crossorigin />',
  '<link rel="preload" href="./shinylive/webr/library.data.gz" as="fetch" crossorigin />'
)

idx <- "docs/index.html"
h <- readChar(idx, file.info(idx)$size, useBytes = TRUE)
h <- sub("  <title>Shiny App</title>",
         paste0("  <title>CrackTime — ¿Cuánto tardaría en descifrar tu contraseña?</title>", inject_head),
         h, fixed = TRUE)
stopifnot(grepl("CrackTime —", h, fixed = TRUE))

loader <- paste(readLines("tools/loading-screen.html", warn = FALSE, encoding = "UTF-8"),
                collapse = "\n")
h <- sub('  <body>', paste0('  <body>', loader), h, fixed = TRUE)
stopifnot(grepl("cracktime-loader", h, fixed = TRUE))
writeChar(h, idx, eos = NULL, useBytes = TRUE)

#favicon y og-image como estáticos de la raíz (para crawlers y first paint)
file.copy("www/assets/favicon.svg", "docs/favicon.svg", overwrite = TRUE)
file.copy("www/assets/og-image.png", "docs/og-image.png", overwrite = TRUE)

sz <- sum(file.info(list.files("docs", recursive = TRUE, full.names = TRUE))$size)
cat(sprintf("Export OK en %.1f s. Tamaño docs/ total: %.1f MB\n", dt, sz / 1e6))
cat("index.html post-procesado: loader + metas og + preload de R.wasm/library.data.gz\n")