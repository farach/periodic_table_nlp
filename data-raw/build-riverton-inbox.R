# Build the fictional Riverton inbox used by tasks 48 and 50.
#
# Run by hand, not during a render. Everything here is invented for teaching.
# No real place, employer, jobseeker, or sender is described.
#
# Usage:
#   Rscript data-raw/build-riverton-inbox.R

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tibble)
  library(tidyr)
  library(purrr)
  library(stringr)
  library(digest)
})

out_dir <- "data/riverton"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

inbox <- tribble(
  ~message_id, ~text, ~is_spam, ~intent,
  "M001", "I applied for the forklift trainee posting last Tuesday and want to check my status.", FALSE, "check_status",
  "M002", "Can you tell me whether my Riverton Works application is still under review?", FALSE, "check_status",
  "M003", "I completed the form for the night warehouse role; has anyone looked at it yet?", FALSE, "check_status",
  "M004", "Please confirm that my documents for the youth internship reached your office.", FALSE, "check_status",
  "M005", "The portal says submitted, but I need to know if the caregiver aide opening is closed.", FALSE, "check_status",
  "M006", "I interviewed on Friday for the bus cleaner job and need an update.", FALSE, "check_status",
  "M007", "I can approve your work from home payroll file once you send the release fee.", TRUE, "check_status",
  "M008", "I'm a recruiter and I can guarantee placement after your $79 verification payment.", TRUE, "check_status",
  "M009", "I lost the confirmation email for the food service class and want to check enrollment.", FALSE, "check_status",
  "M010", "Is my name still on the callback list for the construction helper program?", FALSE, "check_status",
  "M011", "My account will not accept my password after the browser update.", FALSE, "reset_access",
  "M012", "Please reset access for the training portal; the link expired this morning.", FALSE, "reset_access",
  "M013", "I changed phones and cannot receive the sign-in code.", FALSE, "reset_access",
  "M014", "The system locked me out after three tries.", FALSE, "reset_access",
  "M015", "Can someone reopen my account before tonight's orientation?", FALSE, "reset_access",
  "M016", "My email was typed wrong on the job board profile, so I cannot log in.", FALSE, "reset_access",
  "M017", "I froze your applicant wallet for security; send gift cards and I will restore login.", TRUE, "reset_access",
  "M018", "Can I reset your Riverton password after you enter your bank code at this outside link?", TRUE, "reset_access",
  "M019", "I need a new temporary password for the resume workshop registration.", FALSE, "reset_access",
  "M020", "The reset message never arrived for my account.", FALSE, "reset_access",
  "M021", "Am I eligible for the welding class if I finished high school outside the state?", FALSE, "ask_eligibility",
  "M022", "Do I need a driver's license before applying for the delivery helper listing?", FALSE, "ask_eligibility",
  "M023", "Can parents in the evening program still receive transit vouchers?", FALSE, "ask_eligibility",
  "M024", "I am 17 now and turn 18 next month; can I join the summer bridge program?", FALSE, "ask_eligibility",
  "M025", "Does the medical billing course accept people who are still learning English?", FALSE, "ask_eligibility",
  "M026", "I live in Bellhaven but work in Riverton; can I use the lab?", FALSE, "ask_eligibility",
  "M027", "I have a no-experience shipping job for you if you pay the starter kit deposit today.", TRUE, "ask_eligibility",
  "M028", "Do you want me to qualify you for a private grant after a small processing charge?", TRUE, "ask_eligibility",
  "M029", "Do weekend classes count for people receiving unemployment benefits?", FALSE, "ask_eligibility",
  "M030", "Can I apply to the data support certificate with a GED?", FALSE, "ask_eligibility",
  "M031", "Choose childcare support and the job board shows a blank page.", FALSE, "report_problem",
  "M032", "Upload a resume and the file name changes to random letters.", FALSE, "report_problem",
  "M033", "The appointment calendar keeps showing times that are already taken.", FALSE, "report_problem",
  "M034", "A listing says paid training, but the attachment asks for my bank password.", FALSE, "report_problem",
  "M035", "The phone number on the bakery posting is disconnected.", FALSE, "report_problem",
  "M036", "I tried to report a suspicious offer, but the report button failed.", FALSE, "report_problem",
  "M037", "I'm from tech support, and I found an infection; buy this cleanup card before applying!", TRUE, "report_problem",
  "M038", "I represent a recruiter who requires crypto payment for the Lab background check.", TRUE, "report_problem",
  "M039", "The Spanish version of the page cuts off the final question.", FALSE, "report_problem",
  "M040", "The map sends me to the old training entrance.", FALSE, "report_problem",
  "M041", "Please call after 3 p.m. about the healthcare aide class.", FALSE, "request_callback",
  "M042", "Schedule a callback because the online session is not possible to attend.", FALSE, "request_callback",
  "M043", "Can a counselor phone me about which certificate fits warehouse work?", FALSE, "request_callback",
  "M044", "Please leave a voicemail if I miss the call.", FALSE, "request_callback",
  "M045", "I need someone to call my case manager about required paperwork.", FALSE, "request_callback",
  "M046", "Could you call with bus directions to the skills centre?", FALSE, "request_callback",
  "M047", "Call this premium number now to claim your guaranteed job interview.", TRUE, "request_callback",
  "M048", "Should I call back with a remote job offer after you text your card number?", TRUE, "request_callback",
  "M049", "I work mornings, so please call me during lunch about the class waitlist.", FALSE, "request_callback",
  "M050", "Can the intake worker call my parent to explain the program?", FALSE, "request_callback",
  "M051", "Congratulations, you were selected for a secret shopper job; deposit this check today.", TRUE, "check_status",
  "M052", "I need your Social Security number by text to finish your hiring file.", TRUE, "reset_access",
  "M053", "A company using your logo offered a remote packing job and asked for a wire transfer.", FALSE, "report_problem",
  "M054", "Earn $900 weekly mailing packages from home with no interview.", TRUE, "ask_eligibility",
  "M055", "I am not sure whether this offer is real; the recruiter wants a photo of my ID.", FALSE, "report_problem",
  "M056", "Limited slots for city jobs! Pay now in crypto to reserve your badge.", TRUE, "request_callback",
  "M057", "The childcare stipend form says pending. Do I need to send another copy?", FALSE, "check_status",
  "M058", "My office will release your training certificate after the activation fee.", TRUE, "check_status",
  "M059", "I cannot open the document that lists class materials.", FALSE, "report_problem",
  "M060", "Send a deposit for tools and start tomorrow as a warehouse supervisor.", TRUE, "ask_eligibility"
) |>
  mutate(
    author_note = paste(
      "Invented by the site author for a teaching fixture;",
      "not a real message or validated benchmark."
    )
  )

score_binary_feature <- function(data, feature_name) {
  feature_values <- data[[feature_name]]

  orientations <- tibble(
    feature_value_predicting_spam = c(TRUE, FALSE)
  ) |>
    mutate(
      predicted_spam = map(
        feature_value_predicting_spam,
        \(feature_value) feature_values == feature_value
      ),
      accuracy = map_dbl(predicted_spam, \(prediction) {
        mean(prediction == data$is_spam)
      }),
      scam_recall = map_dbl(predicted_spam, \(prediction) {
        sum(prediction & data$is_spam) / sum(data$is_spam)
      }),
      genuine_recall = map_dbl(predicted_spam, \(prediction) {
        sum(!prediction & !data$is_spam) / sum(!data$is_spam)
      })
    )

  best_accuracy_row <- orientations |>
    arrange(desc(accuracy), desc(scam_recall)) |>
    slice(1)

  best_scam_recall_row <- orientations |>
    arrange(desc(scam_recall), desc(accuracy)) |>
    slice(1)

  best_genuine_recall_row <- orientations |>
    arrange(desc(genuine_recall), desc(accuracy)) |>
    slice(1)

  tibble(
    feature = feature_name,
    spam_when_feature_is = best_accuracy_row$feature_value_predicting_spam,
    best_accuracy = best_accuracy_row$accuracy,
    scam_recall_at_best_accuracy = best_accuracy_row$scam_recall,
    genuine_recall_at_best_accuracy = best_accuracy_row$genuine_recall,
    best_scam_recall = best_scam_recall_row$scam_recall,
    spam_when_feature_is_for_best_scam_recall =
      best_scam_recall_row$feature_value_predicting_spam,
    best_genuine_recall = best_genuine_recall_row$genuine_recall,
    spam_when_feature_is_for_best_genuine_recall =
      best_genuine_recall_row$feature_value_predicting_spam
  )
}

superficial_features <- inbox |>
  mutate(
    first_person_pronoun = str_detect(
      text,
      regex("\\b(I|I'm|I’ve|I’d|I’ll|me|my|mine|we|we're|we’ve|us|our|ours)\\b",
        ignore_case = TRUE
      )
    ),
    terminal_question_mark = str_detect(text, "\\?\\s*$"),
    word_count = str_count(text, "\\S+"),
    above_or_equal_median_words = word_count >= median(word_count),
    exclamation_mark = str_detect(text, fixed("!")),
    digit = str_detect(text, "\\d")
  )

superficial_diagnostics <- tibble(
  feature = c(
    "first_person_pronoun",
    "terminal_question_mark",
    "above_or_equal_median_words",
    "exclamation_mark",
    "digit"
  )
) |>
  mutate(result = map(feature, \(feature_name) {
    score_binary_feature(superficial_features, feature_name)
  })) |>
  select(-feature) |>
  unnest(result)

print(
  superficial_diagnostics |>
    mutate(
      across(
        c(
          best_accuracy,
          scam_recall_at_best_accuracy,
          genuine_recall_at_best_accuracy,
          best_scam_recall,
          best_genuine_recall
        ),
        \(value) round(value, 4)
      )
    ),
  n = Inf,
  width = Inf
)

stopifnot(
  max(superficial_diagnostics$best_accuracy) < 0.80,
  max(superficial_diagnostics$best_scam_recall) < 0.95
)

inbox_path <- file.path(out_dir, "riverton-inbox.csv")
write_csv(inbox, inbox_path)

spam_counts <- inbox |>
  count(is_spam, name = "rows") |>
  mutate(class = if_else(is_spam, "job scam", "genuine message")) |>
  select(class, rows)

intent_counts <- inbox |>
  count(intent, name = "rows") |>
  arrange(intent)

metadata <- tibble(
  artifact = "riverton-inbox.csv",
  description = "Invented short inbox messages with spam and intent labels",
  source = "Created for this project",
  license = "MIT, same as this repository",
  created_on = "2026-08-29",
  purpose = paste(
    "Mechanics only. A dataset written by the same person who writes the",
    "classifier cannot measure whether the method works."
  ),
  rows = nrow(inbox),
  spam_class_counts = paste(
    paste(spam_counts$class, spam_counts$rows, sep = "="),
    collapse = "; "
  ),
  intent_class_counts = paste(
    paste(intent_counts$intent, intent_counts$rows, sep = "="),
    collapse = "; "
  ),
  fingerprint = digest(
    paste(read_lines(inbox_path), collapse = "\n"),
    algo = "sha256",
    serialize = FALSE
  )
)

write_csv(metadata, file.path(out_dir, "riverton-inbox-metadata.csv"))

cat("wrote:\n")
print(
  tibble(file = c(inbox_path, file.path(out_dir, "riverton-inbox-metadata.csv"))) |>
    mutate(bytes = file.size(file))
)
