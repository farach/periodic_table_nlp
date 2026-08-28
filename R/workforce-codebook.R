workforce_label_definitions <- c(
  training = paste(
    "Choose training when the sentence explicitly offers or describes",
    "a learning program, mentoring, certification training,",
    "an apprenticeship, a class, or training-linked support.",
    "A credential that is required or preferred is not training",
    "unless the sentence also says learning is offered."
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
    "or classes occur. If a sentence says a shift is required,",
    "schedule takes precedence because timing is the main claim."
  ),
  skill = paste(
    "Choose skill when the main claim names an ability used in work.",
    "Do not infer a skill from a job title."
  ),
  other = paste(
    "Choose other when none of the four definitions applies.",
    "Headings, deadlines, location, work setting, and travel are other",
    "unless the sentence explicitly states another category."
  )
)

workforce_codebook <- function() {
  labels <- names(workforce_label_definitions)
  definitions <- paste0(
    labels,
    ": ",
    unname(workforce_label_definitions)
  )

  instructions <- paste(
    c(
      "Annotation unit: one sentence with its document identifier.",
      "Use only information explicitly stated in the sentence.",
      "Choose one label for the sentence's main claim.",
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
      "Short explanation using only the sentence"
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
      rationale = "The sentence explicitly offers training.",
      uncertainty = "certain"
    ),
    list(
      text = "A portfolio is required.",
      label = "requirement",
      rationale = "The sentence states an application requirement.",
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
      rationale = "The sentence names an ability used in work.",
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

  foundryR::foundry_codebook(
    name = "workforce-information",
    version = "1.0.0",
    instructions = instructions,
    schema = schema,
    examples = examples
  )
}
