# Modernization notes

**Research checked:** 2026-09-25

The 81-tile map is a mnemonic inherited from an earlier view of NLP. It remains
useful as a list of questions, but it is not a settled taxonomy. The map mixes
tasks, methods, objectives, resources, services, applications, and work done
across a model's life. `data/periodic_table.csv` records those item types so the
site does not hide the mixture.

## Language models as research instruments

The largest recent change in practice is not a new tile. A language model now
sits inside many ordinary text analyses as an annotator, classifier, extractor,
judge, retriever, or coding assistant, next to the classic methods the lessons
teach. The guide page `using-language-models.qmd` teaches the working pattern:
record the instrument, save its outputs, rerun a sample, check a random sample
against people, and correct any estimate for the model's errors. The evidence
behind it, labelled as in `RESEARCH_STANDARDS.md` and checked on 2026-09-25:

- **Disputed in scope.** Model annotation matches or beats crowd workers on
  some tasks (Gilardi, Alizadeh, and Kubli 2023, PNAS) and is inconsistent on
  others, where a small supervised model does better (Kristensen-McLachlan et
  al. 2025, PNAS Nexus).
- **Current practice.** A full codebook with definitions and edge cases
  improves reliability more than prompt rewording (Halterman and Keith,
  Political Analysis; Çelebi and Penczynski 2026, PLOS ONE).
- **Established.** Labels that agree with people 80 to 90 percent of the time
  can still bias downstream estimates. Corrections that use a random
  human-labelled sample restore valid intervals: prediction-powered inference
  (Angelopoulos et al. 2023, Science), design-based supervised learning (Egami
  et al., NeurIPS 2023), and confidence-driven inference (Gligorić et al.,
  NAACL 2025). R implementations: `ipd` on CRAN, `dsl` on GitHub, and
  `mixedsubjects` on CRAN.
- **Established.** Nominally deterministic settings do not reproduce across
  runs or hosts (Atil et al., Eval4NLP 2025), because server batching and
  floating-point order change greedy choices (Thinking Machines Lab 2025; Ye et
  al., NeurIPS 2025). Formatting changes alone can move accuracy by many points
  (Sclar et al., ICLR 2024), and a hosted model can change under a fixed name
  (Chen, Zaharia, and Zou 2024, Harvard Data Science Review).
- **Current practice.** Report the model version, prompt, settings, and
  validation with a checklist: GUIDE-LLM for behavioural science (Feuerriegel et
  al. 2026, Nature Human Behaviour) or TRIPOD-LLM for biomedicine (Gallifant et
  al. 2025, Nature Medicine).
- **Current practice.** Model judges agree with people on some evaluation tasks
  and not others, so each judge needs task-specific validation (Bavaresco et
  al., ACL 2025); position and self-preference biases are documented.
- **Current practice.** With a few hundred labelled examples for a stable task,
  fine-tuned small models often match or beat prompting (Edwards and
  Camacho-Collados, LREC-COLING 2024).
- **Emerging.** Schema-constrained output guarantees format, not content, and
  answer-before-reasoning schemas can lower accuracy (Tam et al., EMNLP 2024
  Industry Track; JSONSchemaBench 2025 preprint).
- **Emerging.** Coding agents that run analyses make different data-preparation
  choices from run to run (BLADE, Findings of EMNLP 2024; Cui and Alexander 2026
  preprint). Peer-reviewed guidance asks scientists to read and rerun the code
  (Bridgeford et al. 2026, PLOS Computational Biology).
- **Current practice.** Retrieval pairs a lexical and a dense list, and newer
  open embedding models lead public benchmarks such as MMTEB (2025), but a
  benchmark rank does not replace judgments on one's own queries.

R packages checked the same day: ellmer 0.5.0, mall 0.2.0, ragnar 0.3.1,
vitals 0.4.0, tidyllm 0.6.0, text 1.9, and ipd 0.4.1. Short notes pointing to
the guide were added to lessons 8, 44, 51, 69, 70, and 72.

Open questions to revisit: whether correction methods become a reviewer
expectation; whether batch-invariant inference becomes a standard option;
whether reporting checklists are enforced; and whether automated faithfulness
judges become reliable on hard cases.

## Topics that remain foundational

Character encoding, regular expressions, file loading, API requests, document
boundaries, and data provenance remain necessary. Their core definitions have
not been replaced by large language models. Current tools can automate parts of
the work, but they still receive bytes, text, records, and documents whose
origin and meaning must be checked.

## Completed coverage that still needs review

Lessons 14, 27, and 32 are available. Their current pages introduce subword
tokenization, named-entity recognition, and entity linking, respectively.
Future revisions should continue to test their claims against current
tokenizers, prompted or structured-output extraction, and normalization-aware
linking rather than treating publication as permanent completion.

All 81 tiles have lessons. The systems lessons, 69 through 74, teach relation
extraction with a stated schema, knowledge base population with provenance,
retrieve-then-read question answering with citation screens, a dialogue state
kept outside the model, lexical and embedding search indexes, and review
workflows that estimate what was missed. They use small constructed fixtures
and local models, so they demonstrate mechanisms rather than measure current
systems. Revisit them when citation-faithfulness evaluation, prompt-injection
defenses, or embedding-model practice changes.

## Areas to keep reviewing

Later research should give extra attention to:

- Tasks 43 through 47, model development: distinguish pretraining, task
  training, instruction tuning, preference-based post-training, evaluation,
  deployment, and monitoring.
- Tasks 48 through 52, classification: compare trained classifiers,
  fine-tuning, and zero- or few-shot prompting.
- Tasks 54 and 66, summarization: separate extractive and generative methods
  and evaluate factual support, not fluency alone.
- Tasks 58 through 62, similarity: distinguish lexical resources, sparse
  retrieval, static vectors, contextual representations, and sentence
  embeddings.
- Task 63, next-token prediction: present it as one training objective, not a
  synonym for every language model.
- Tasks 69 through 74, systems: include retrieval-augmented generation, tool
  use, agent-like loops, citation support, and safety testing when relevant.

## Decoding and inference

Do not describe greedy decoding or beam search as brute force. Do not claim that
Monte Carlo methods have replaced deterministic decoding. The suitable method
depends on the task, verifier, compute budget, and cost of an error.

Teach greedy decoding, beam search, temperature, top-k and nucleus sampling,
best-of-N selection, self-consistency, and tree search as different design
choices. Tree search is an active research area for reasoning and planning; it
is not a universal replacement for simpler decoding.

## Cross-cutting questions

When they affect the task, a lesson should ask:

- Was a transformer or pretrained foundation model used?
- What data produced the model, and was its use licensed and expected?
- Does retrieval supply current or private information?
- Can the system call tools or take actions outside text generation?
- Which languages, regions, and user groups were tested?
- Are image, audio, or other non-text inputs involved?
- How were factuality, safety, uncertainty, cost, and failure measured?

These questions should appear only where they help. A character-encoding lesson
does not need an LLM section.

## Starting references

- [Attention Is All You Need](https://arxiv.org/abs/1706.03762)
- [BERT: Pre-training of Deep Bidirectional Transformers](https://aclanthology.org/N19-1423/)
- [Sentence-BERT](https://arxiv.org/abs/1908.10084)
- [Retrieval-Augmented Generation](https://arxiv.org/abs/2005.11401)
- [The Curious Case of Neural Text Degeneration](https://arxiv.org/abs/1904.09751)
- [Self-Consistency Improves Chain of Thought Reasoning](https://arxiv.org/abs/2203.11171)
- [SC-MCTS*: an emerging tree-search approach for language-model reasoning](https://arxiv.org/abs/2410.01707)
- [Data Statements for Natural Language Processing](https://aclanthology.org/Q18-1041/)
- [Datasheets for Datasets](https://doi.org/10.1145/3458723)
- [Model Cards for Model Reporting](https://arxiv.org/abs/1810.03993)
