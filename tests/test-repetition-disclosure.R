# Read the exact exception list without importing the lesson runtime.
assignments <- Filter(
  \(entry) is.call(entry) && length(entry) == 3L &&
    identical(entry[[1]], as.name("<-")) &&
    identical(entry[[2]], as.name("allowed_repeats")),
  as.list(parse("scripts/check-repetition.R"))
)
stopifnot(length(assignments) == 1L)
allowed <- eval(assignments[[1]], envir = new.env(parent = baseenv()))

expected <- c(
  paste(
    "The Riverton Workforce Lab, its job board, and its training flyer are",
    "fictional and were created for teaching."
  ),
  paste(
    "The author created the fictional Riverton Workforce Lab, its job board,",
    "and its training flyer for teaching."
  )
)
ordinary <- "The author created an unrelated result for this lesson."
sentences <- rep(c(expected, ordinary), each = 4L)
remaining <- sentences[!sentences %in% allowed]

stopifnot(
  identical(allowed, expected),
  identical(remaining, rep(ordinary, 4L)),
  !paste(expected[[2]], "An unrelated claim follows.") %in% allowed
)
cat("Exact disclosure-exception regression passed.\n")
