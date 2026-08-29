# Modernization notes

**Research checked:** 2026-08-28

The 81-tile map is a mnemonic inherited from an earlier view of NLP. It remains
useful as a list of questions, but it is not a settled taxonomy. The map mixes
tasks, methods, objectives, resources, services, applications, and work done
across a model's life. `data/periodic_table.csv` records those item types so the
site does not hide the mixture.

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

## Future lessons

Future research should give extra attention to:

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
