# Point R at the project's Python environment and start spaCy.
#
# spaCy is a Python library. The spacyr package talks to it through reticulate,
# so R has to be told which Python to use before spacyr starts. Lessons call
# this file with source("R/use-spacy.R") rather than repeating the setup.
#
# If the environment is missing, this stops with instructions instead of
# failing somewhere less obvious.

use_project_spacy <- function(model = "en_core_web_sm",
                              venv = ".venv-spacy") {
  candidates <- c(
    file.path(venv, "bin", "python"),
    file.path(venv, "Scripts", "python.exe")
  )
  found <- candidates[file.exists(candidates)]

  if (length(found) == 0L) {
    stop(
      paste0(
        "No Python environment found at '", venv, "'.\n",
        "Create it once with:\n",
        "  python -m venv ", venv, "\n",
        "  ", venv, "/bin/python -m pip install -r requirements-spacy.txt\n",
        "On Windows the second path is ", venv, "/Scripts/python."
      ),
      call. = FALSE
    )
  }

  if (!requireNamespace("reticulate", quietly = TRUE)) {
    stop("The reticulate package is not installed.", call. = FALSE)
  }

  if (!requireNamespace("spacyr", quietly = TRUE)) {
    stop("The spacyr package is not installed.", call. = FALSE)
  }

  python <- normalizePath(found[[1]], winslash = "/")

  # Bind reticulate explicitly. Setting RETICULATE_PYTHON alone is not enough,
  # because it is ignored once Python has been initialised, and reticulate may
  # otherwise pick an interpreter that has no spaCy in it.
  Sys.setenv(RETICULATE_PYTHON = python)
  reticulate::use_python(python, required = TRUE)

  if (!reticulate::py_module_available("spacy")) {
    stop(
      paste0(
        "The Python at '", python, "' has no spaCy module.\n",
        "Install it with:\n",
        "  ", venv, "/bin/python -m pip install -r requirements-spacy.txt"
      ),
      call. = FALSE
    )
  }

  # spacyr's own Python helper contains an unescaped backslash, so importing it
  # prints a SyntaxWarning that has nothing to do with the lesson. Silence it at
  # the Python end before anything is imported, so pages stay clean.
  reticulate::py_run_string(
    paste(
      "import warnings",
      "warnings.filterwarnings('ignore', category=SyntaxWarning)",
      sep = "\n"
    )
  )

  # spacyr announces itself on startup, and reticulate can pass through
  # warnings from Python that R would otherwise treat as fatal. Neither is
  # useful on a published page, so the confirmation is returned instead.
  suppressMessages(
    suppressWarnings(
      spacyr::spacy_initialize(model = model)
    )
  )

  invisible(
    list(
      python = python,
      model = model
    )
  )
}

# The version of the pipeline actually loaded, so a lesson can print it rather
# than trusting a number written in prose.
spacy_pipeline_version <- function() {
  reticulate::py_run_string(
    paste(
      "import spacy",
      "_meta = spacy.load('en_core_web_sm').meta",
      "_info = {'name': _meta['name'],",
      "         'version': _meta['version'],",
      "         'lang': _meta['lang'],",
      "         'license': _meta['license'],",
      "         'spacy': spacy.__version__}",
      sep = "\n"
    ),
    convert = TRUE
  )$`_info`
}
