# Research standards

Natural language processing changes quickly. A lesson must separate durable
ideas from methods that are popular at one point in time.

## Classify each important claim

Use one of these labels in research notes:

- **Established:** supported by replicated work or long-standing technical
  standards.
- **Current practice:** widely used now, with the date and scope stated.
- **Emerging:** supported by early research but not settled across settings.
- **Disputed:** credible evidence points in different directions.
- **Speculative:** a possibility that has not been established.

The label guides the wording. An emerging result must not be written as a rule.

## Prefer evidence close to the claim

Use sources in this order when possible:

1. Technical standards and peer-reviewed primary research.
2. Official documentation, model cards, and dataset documentation.
3. Reproducible evaluations with a stated dataset, metric, and baseline.
4. Peer-reviewed surveys.
5. Preprints, conference talks, and technical reports.
6. Vendor posts and general tutorials.

Lower items can be useful, but they need stronger qualification. A vendor's
benchmark does not independently establish that vendor's model is better.

## Record the research trail

For each lesson, keep:

- the question being checked;
- the search date;
- the software, model, dataset, or API version;
- the strongest supporting source;
- the strongest credible counterevidence;
- the populations, languages, domains, and time periods covered;
- licensing, consent, and provenance concerns; and
- a note about what remains unknown.

The current review record lives in `data/lesson_reviews.csv`. An available
lesson may still have human approval marked as pending. Availability means that
the page can be read, not that every claim has final approval.

Search for criticism before drafting the conclusion. If a result has not been
replicated, say so.

## Check the modern NLP context

Later lessons should consider these developments when they affect the task:

- transformer architectures and pretrained foundation models;
- subword tokenization and contextual representations;
- instruction tuning and preference-based post-training;
- dense embeddings and retrieval-augmented generation;
- tool use and agent-like systems;
- multilingual and multimodal inputs;
- data provenance, consent, bias, safety, and environmental cost; and
- evaluation that measures reliability rather than fluency alone.

Do not force every topic into every lesson. Character encoding does not need an
LLM section. Corpus construction does need provenance and consent because large
models depend on collected text.

## Describe decoding methods precisely

The phrase "brute force prediction" is not a standard substitute for greedy
decoding or beam search. Greedy decoding chooses the most likely next token.
Beam search keeps several candidate sequences. Neither method exhaustively
tests every possible sequence.

Sampling, top-k and nucleus sampling, best-of-N selection, self-consistency, and
Monte Carlo tree search answer different needs. Evidence does not support a
single ranking that applies to every task.

- Greedy decoding selects the highest-probability next token.
- Beam search retains several partial sequences and scores their continuations.
- Temperature, top-k, and nucleus sampling change which next tokens can be
  sampled and with what probabilities.
- Best-of-N and self-consistency generate several complete candidates and apply
  a selection or voting rule.
- Monte Carlo tree search requires a defined state, available actions, a rule
  for choosing and expanding branches, an evaluator or rollout, and a way to
  send values back through the tree. A node may represent a token, a reasoning
  step, or a tool action; these are different algorithms.

Future lessons must state the task, model, search unit, evaluator, baseline,
evaluation data, uncertainty, compute budget, and failure conditions before
claiming one decoding method performs better than another.

## Evaluate more than fluency

A fluent answer can still be false, unsafe, copied, unstable, or useless for
the intended setting. Model evaluations must record:

1. the construct the test is meant to measure;
2. the baseline and comparison conditions;
3. possible overlap between training and evaluation data;
4. repeated runs and uncertainty when output is stochastic;
5. performance by language, domain, and affected group where relevant;
6. human-rating instructions and agreement when people score the output;
7. cost, latency, and resource use;
8. predictable failure cases and adversarial tests; and
9. whether a benchmark result transfers to the intended use.

Use behavior-focused tests such as CheckList alongside aggregate benchmark
scores. For generative systems, evaluate factual support, citation faithfulness,
and harmful failures rather than treating eloquence as correctness.

## Gate causal claims

If a lesson says that one intervention causes an outcome, its notes must name
the intervention, outcome, comparison or counterfactual, identifying
assumptions, plausible confounders, and conditions under which the conclusion
would fail. A citation count cannot repair an unidentified causal claim.

## Minimum source set for a fast-moving lesson

A lesson about models or modern methods needs:

1. one primary paper or technical standard;
2. one official implementation or model document;
3. one independent evaluation or replication when available; and
4. one source focused on limitations, failures, or affected groups.

Recheck links and time-sensitive claims immediately before publication.

## Foundational references for future research

- [Attention Is All You Need](https://arxiv.org/abs/1706.03762)
- [Retrieval-Augmented Generation for Knowledge-Intensive NLP Tasks](https://arxiv.org/abs/2005.11401)
- [The Curious Case of Neural Text Degeneration](https://arxiv.org/abs/1904.09751)
- [Self-Consistency Improves Chain of Thought Reasoning](https://arxiv.org/abs/2203.11171)
- [A Survey of Monte Carlo Tree Search Methods](https://doi.org/10.1109/TCIAIG.2012.2186810)
- [Holistic Evaluation of Language Models](https://arxiv.org/abs/2211.09110)
- [Beyond Accuracy: Behavioral Testing of NLP Models with CheckList](https://aclanthology.org/2020.acl-main.442/)
- [NIST AI 600-1: Generative AI Profile](https://doi.org/10.6028/NIST.AI.600-1)
- [Data Statements for Natural Language Processing](https://aclanthology.org/Q18-1041/)
- [Datasheets for Datasets](https://arxiv.org/abs/1803.09010)
- [Model Cards for Model Reporting](https://arxiv.org/abs/1810.03993)
