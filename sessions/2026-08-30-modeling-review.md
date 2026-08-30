# Manual review: teaching model development without losing the NLP task

Lesson 43 originally jumped from a train/test split into `step_*()` calls,
`logistic_reg()`, a workflow, and a fit. The code ran, but a learner had no map
of the objects or any reason to believe the one model shown was a defensible
choice.

## Rules carried forward

1. Define the jobs before showing the pipeline: recipe, recipe step, model
   specification, engine, workflow, fit, and prediction.
2. Split off the final test set before comparing models. Model selection and
   tuning happen only inside the training data.
3. Resample at the independent unit. Paragraphs from one speech stay together,
   so this project uses folds grouped by `speech_id`.
4. Compare a few candidates that teach different ideas. More models do not make
   a comparison better.
5. Choose the selection metric before seeing results. Balanced accuracy is
   primary for the era task because the class counts differ.
6. A tie is not a win. When candidates are statistically indistinguishable,
   prefer the one that is simpler to inspect or maintain and state that reason.
7. Candidate selection, final testing, and robustness checks answer different
   questions. Do not call repeated holdouts fresh final tests.
8. Keep expensive resampling in `data-raw/` with committed results. The lesson
   should still create the split and folds, fit one model, and score the final
   test live.
9. A deployment record includes the chosen family, tuning values, selection
   design, final test, and baseline.
10. Monitoring must reproduce the fitted preprocessing. A drift check that uses
    a different stop-word list is measuring a different pipeline.

## What changed

`data-raw/build-model-comparison.R` compares ridge logistic regression, lasso
logistic regression, and a random forest across five grouped folds inside the
46 training speeches. It tests 14 candidate settings. The final 14 speeches are
not available to the comparison.

An early grid put ridge penalties `0.001` and `0.01` at the same 0.8008 mean
balanced accuracy. A coefficient check showed they were the same fitted
endpoint, not two models with equal scores: both requested values sat below the
smallest value in glmnet's ridge path. The final comparison uses model-specific
grids instead of keeping a duplicate.

Ridge at `0.01` leads the final comparison at 0.8008 mean balanced accuracy,
followed by ridge at `0.1` (0.7901), lasso at `0.001` (0.7809), and the leading
random forest (0.7761). Keeping the leading linear model preserves the
coefficients used in lesson 45. The overlapping fold summaries still do not
establish a universal best model.

Lesson 44 keeps the older 10 repeated holdouts as a robustness check. Those
resamples show sensitivity to which speeches land on each side; they no longer
double as model selection.
