workforce_label_definitions <- c(
  training = paste(
    "Choose training when the text unit explicitly offers or describes",
    "a learning program, mentoring, certification training,",
    "an apprenticeship, a class, or training-linked support.",
    "A credential that is required or preferred is not training",
    "unless the text unit also says learning is offered."
  ),
  requirement = paste(
    "Choose requirement when the main claim states or prefers",
    "experience, education, a credential, a license, a portfolio,",
    "a physical condition, or another entry condition.",
    "A negated requirement, such as no prior experience required,",
    "still describes an entry condition."
  ),
  schedule = paste(
    "Choose schedule when the main claim states when work, training,",
    "or classes occur. If a text unit says a shift is required,",
    "schedule takes precedence because timing is the main claim."
  ),
  skill = paste(
    "Choose skill when the main claim names an ability used in work.",
    "Do not infer a skill from a job title."
  ),
  other = paste(
    "Choose other when none of the four definitions applies.",
    "Headings, deadlines, location, work setting, and travel are other",
    "unless the text unit explicitly states another category."
  )
)

workforce_codebook <- function(version = "1.1.0") {
  stopifnot(version %in% c("1.0.0", "1.1.0"))
  legacy <- identical(version, "1.0.0")
  labels <- names(workforce_label_definitions)
  label_definitions <- if (legacy) {
    gsub(
      "text unit",
      "sentence",
      workforce_label_definitions,
      fixed = TRUE
    )
  } else {
    workforce_label_definitions
  }
  definitions <- paste0(
    labels,
    ": ",
    unname(label_definitions)
  )
  unit_instructions <- if (legacy) {
    c(
      "Annotation unit: one sentence with its document identifier.",
      "Use only information explicitly stated in the sentence.",
      "Choose one label for the sentence's main claim."
    )
  } else {
    c(
      "Annotation unit: one source-text line with its document identifier.",
      "Use only information explicitly stated in the text unit.",
      "Choose one label for the text unit's main claim."
    )
  }

  instructions <- paste(
    c(
      unit_instructions,
      definitions,
      paste(
        "Set uncertainty to needs_review when more than one label",
        "remains defensible after applying the definitions.",
        "Otherwise set uncertainty to certain."
      ),
      paste(
        "Write a short rationale that identifies the words",
        "supporting the decision."
      )
    ),
    collapse = "\n"
  )

  schema <- foundryR::foundry_schema(
    label = foundryR::type_enum(
      desc = "Primary workforce-information label",
      values = labels
    ),
    rationale = foundryR::type_string(
      if (legacy) {
        "Short explanation using only the sentence"
      } else {
        "Short explanation using only the text unit"
      }
    ),
    uncertainty = foundryR::type_enum(
      desc = "Whether the item needs adjudication",
      values = c("certain", "needs_review")
    )
  )

  examples <- list(
    list(
      text = "Paid training is provided.",
      label = "training",
      rationale = "The text unit explicitly offers training.",
      uncertainty = "certain"
    ),
    list(
      text = "A portfolio is required.",
      label = "requirement",
      rationale = "The text unit states an application requirement.",
      uncertainty = "certain"
    ),
    list(
      text = "Weekend shifts are required.",
      label = "schedule",
      rationale = "The main claim states when work occurs.",
      uncertainty = "needs_review"
    ),
    list(
      text = "Clear writing is an essential skill.",
      label = "skill",
      rationale = "The text unit names an ability used in work.",
      uncertainty = "certain"
    ),
    list(
      text = "Applications close on October 15.",
      label = "other",
      rationale = "A deadline is outside the four substantive labels.",
      uncertainty = "certain"
    ),
    list(
      text = "DATA SUPPORT CERTIFICATE",
      label = "other",
      rationale = "A heading alone does not state that training is offered.",
      uncertainty = "needs_review"
    ),
    list(
      text = "A medical records certificate is preferred.",
      label = "requirement",
      rationale = "The main claim prefers a credential.",
      uncertainty = "needs_review"
    )
  )
  if (legacy) {
    examples <- lapply(
      examples,
      function(example) {
        example$rationale <- gsub(
          "text unit",
          "sentence",
          example$rationale,
          fixed = TRUE
        )
        example
      }
    )
  }

  foundryR::foundry_codebook(
    name = "workforce-information",
    version = version,
    instructions = instructions,
    schema = schema,
    examples = examples
  )
}
