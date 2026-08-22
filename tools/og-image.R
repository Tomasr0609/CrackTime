#tools/og-image.R — Genera www/assets/og-image.png (1200x630)

out <- "www/assets/og-image.png"

windowsFonts(segoe = windowsFont("Segoe UI"))

png(out, width = 1200, height = 630)
par(mar = c(0, 0, 0, 0), bg = "#0b0f14")

plot.new()
plot.window(xlim = c(0, 1200), ylim = c(0, 630))

for (i in seq(1, 0, length.out = 120)) {
  rect(0, 0, 1200, 630,
       col = rgb(14, 26, 34, alpha = 255 * (1 - i) * 0.5, maxColorValue = 255),
       border = NA)
}

rect(0, 0, 1200, 14, col = "#00e5a0", border = NA)
rect(0, 616, 1200, 630, col = "#00e5a0", border = NA)

text(600, 500, "CrackTime", family = "segoe", font = 2, cex = 11, col = "#00e5a0")
text(600, 390, "¿Cuánto tardaría una computadora en descifrar tu contraseña?",
     family = "segoe", cex = 3.0, col = "#e6edf3")

#Diseño de medidor qué tan fuerte es tu pw
seg <- 26
for (i in 0:(seg - 1)) {
  x0 <- 470 + i * 10
  col <- if (i < 8) "#ff5d5d" else if (i < 16) "#ffb020" else if (i < 22) "#58d68d" else "#00e5a0"
  rect(x0, 220, x0 + 6.4, 268, col = col, border = NA)
}
text(600, 176, "débil · media · fuerte · muy fuerte",
     family = "segoe", cex = 2.1, col = "#8b949e")

text(600, 96, "Calculado 100% en tu navegador — tu contraseña nunca sale de tu dispositivo",
     family = "segoe", cex = 2.1, col = "#8b949e")

dev.off()

cat("og-image generada en", out, "\n")
