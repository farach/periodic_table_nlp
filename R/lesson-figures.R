# Shared look for lesson figures.
#
# A lesson sources this file once and adds theme_lesson() to a plot. The file
# registers the bundled Source Sans 3 font, the typeface the site uses for its
# text, so figures read like the page around them on every platform. Knitr
# draws figures with ragg (set in _quarto.yml), and ragg finds fonts that are
# registered this way. Sourcing the file does not change any ggplot2 default.

lesson_font <- local({
  family <- "Lesson Sans"

  if (!family %in% systemfonts::registry_fonts()$family) {
    systemfonts::register_font(
      name = family,
      plain = "fonts/SourceSans3-Regular.ttf",
      bold = "fonts/SourceSans3-Semibold.ttf"
    )
  }

  family
})

# Okabe-Ito hues stay distinguishable for the common forms of colour-vision
# deficiency. `accent` marks what the reader should look at first, `contrast`
# marks the comparison or the problem, and `context` is for marks that only
# give the picture its shape. Every figure adds a second cue, such as a label,
# shape, or line type, so no reading depends on colour alone.
lesson_colours <- c(
  ink = "#1D2733",
  body = "#35414D",
  muted = "#55616D",
  grid = "#E3E7EC",
  context = "#BCC5CE",
  accent = "#0072B2",
  contrast = "#D55E00",
  support = "#009E73",
  paper = "#FFFFFF"
)

# Text drawn in a series colour must still reach 4.5:1 against white. The
# vermilion and green hues fall short at text sizes, so labels use these darker
# versions of the same hues.
lesson_text_colours <- c(
  accent = "#0072B2",
  contrast = "#A84A00",
  support = "#00755A"
)

theme_lesson <- function(base_size = 12, grid = c("x", "y", "both", "none")) {
  grid <- match.arg(grid)
  half_line <- base_size / 2

  theme <- ggplot2::theme_minimal(
    base_size = base_size,
    base_family = lesson_font
  ) +
    ggplot2::theme(
      text = ggplot2::element_text(colour = lesson_colours[["ink"]]),
      plot.title = ggtext::element_markdown(
        face = "bold",
        size = ggplot2::rel(1.22),
        lineheight = 1.1,
        margin = ggplot2::margin(b = half_line * 0.5)
      ),
      plot.subtitle = ggtext::element_markdown(
        size = ggplot2::rel(0.95),
        colour = lesson_colours[["muted"]],
        lineheight = 1.25,
        margin = ggplot2::margin(b = half_line * 1.5)
      ),
      plot.caption = ggtext::element_markdown(
        size = ggplot2::rel(0.8),
        colour = lesson_colours[["muted"]],
        hjust = 0,
        lineheight = 1.2,
        margin = ggplot2::margin(t = half_line * 1.5)
      ),
      plot.title.position = "plot",
      plot.caption.position = "plot",
      axis.title = ggplot2::element_text(
        size = ggplot2::rel(0.88),
        colour = lesson_colours[["muted"]]
      ),
      axis.text = ggplot2::element_text(
        size = ggplot2::rel(0.88),
        colour = lesson_colours[["body"]]
      ),
      axis.ticks = ggplot2::element_blank(),
      panel.grid.major = ggplot2::element_line(
        colour = lesson_colours[["grid"]],
        linewidth = 0.4
      ),
      panel.grid.minor = ggplot2::element_blank(),
      strip.text = ggplot2::element_text(
        face = "bold",
        hjust = 0,
        size = ggplot2::rel(0.92),
        margin = ggplot2::margin(b = half_line * 0.6)
      ),
      legend.position = "top",
      legend.justification = "left",
      legend.title = ggplot2::element_text(
        size = ggplot2::rel(0.88),
        colour = lesson_colours[["muted"]]
      ),
      legend.text = ggplot2::element_text(size = ggplot2::rel(0.88)),
      plot.background = ggplot2::element_rect(
        fill = lesson_colours[["paper"]],
        colour = NA
      ),
      plot.margin = ggplot2::margin(
        half_line * 1.5,
        half_line * 2,
        half_line * 1.5,
        half_line * 1.5
      )
    )

  theme + switch(
    grid,
    x = ggplot2::theme(panel.grid.major.y = ggplot2::element_blank()),
    y = ggplot2::theme(panel.grid.major.x = ggplot2::element_blank()),
    both = ggplot2::theme(),
    none = ggplot2::theme(panel.grid.major = ggplot2::element_blank())
  )
}

# Colour a word in a title or subtitle so the sentence doubles as the key.
lesson_key <- function(label, colour) {
  sprintf("<span style='color:%s'>**%s**</span>", colour, label)
}
