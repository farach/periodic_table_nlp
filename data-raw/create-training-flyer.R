transcript_path <- file.path(
  "data",
  "workforce",
  "training-flyer-ground-truth.txt"
)
output_path <- file.path(
  "data",
  "workforce",
  "training-flyer.png"
)

flyer_lines <- readLines(
  transcript_path,
  encoding = "UTF-8",
  warn = TRUE
)
stopifnot(
  identical(length(flyer_lines), 6L)
)

vertical_positions <- c(
  0.84,
  0.68,
  0.52,
  0.41,
  0.30,
  0.15
)
font_sizes <- c(2.1, 1.65, 1.45, 1.45, 1.45, 1.35)
font_faces <- c(2, 2, 1, 1, 1, 2)
font_colors <- c(
  "#183153",
  "#000000",
  "#000000",
  "#000000",
  "#000000",
  "#183153"
)

grDevices::png(
  filename = output_path,
  width = 1200,
  height = 800,
  res = 150,
  bg = "white"
)

graphics::par(
  mar = rep(0, 4),
  family = "HersheySans"
)
graphics::plot.new()
graphics::rect(
  0.03,
  0.03,
  0.97,
  0.97,
  border = "#183153",
  lwd = 8
)

for (line_number in seq_along(flyer_lines)) {
  graphics::text(
    0.5,
    vertical_positions[line_number],
    flyer_lines[line_number],
    cex = font_sizes[line_number],
    font = font_faces[line_number],
    col = font_colors[line_number]
  )
}

grDevices::dev.off()

image <- png::readPNG(
  output_path,
  info = TRUE
)
dimensions <- attr(image, "dim")

stopifnot(
  file.exists(output_path),
  identical(
    as.integer(dimensions[1:2]),
    c(800L, 1200L)
  ),
  file.info(output_path)$size > 5000
)
