# 0.0.90
* Add default-on JSONL checkpoint/resume for Parakeet parser and transformer stages so a mid-stage crash no longer duplicates records on retry. Set `OPENC_BOT_JSONL_CHECKPOINT=0` to restore append-to-final behaviour. `CHECKPOINT_EVERY` (default 1000) controls how often the partial file is fsynced.

# 0.0.1
* Initial commit
