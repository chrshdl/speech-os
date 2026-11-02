# Models

The image build copies the acoustic model and the language model from this
directory onto the `/data` partition of the image, as `/data/speech/<name>`,
and writes `/data/etc/speech-backend` with the arguments that
`speech-backend.service` starts `backend.py` with. They are not in git.

This directory must hold:

- exactly one acoustic model, a streaming CTC model exported to `.onnx` by
  speech's `export.py`,
- at most one word LM `.npz` from `speech.models.word_lm`.

Copy or symlink them here, for example from a speech checkout next to this
repository:

```sh
ln -s ../../speech/examples/commonvoice/models/ctc_streaming_3750h_epoch4/best_model-int8.onnx models/
ln -s ../../speech/examples/librispeech/models/lm-librispeech.npz models/
```

`SPEECH_MODELS_DIR=/some/dir` in the environment of the build uses another
directory instead.

## Decoding settings

`backend-args`, which is in git, holds more arguments for `backend.py`,
appended to `SPEECH_ARGS`: the decoding settings that speech's `tune_lm.py`
found best for these models, such as `--lm-weight 0.5 --word-bonus 4
--unk-penalty 0`, since the best depend on both the acoustic model and the
LM. Lines starting with `#` are comments. Without it, the backend decodes
with its defaults. Change it together with the models.

## Songs

`songs/*.json` here, which may be none, go to `/data/speech/songs`: the
songs the backend plays when asked, such as "play la le lu" (`--songs`, see
speech's `speech/backend/songs.py`; `examples/songs/from_midi.py` makes one
from a MIDI file). Only the `.json` files are copied, so notes on how a
song was made, or its MIDI file, can sit next to it. Like the models they
are not in git, which suits songs still under copyright.

## Voice

`voice/` here holds at most one [Piper](https://github.com/OHF-Voice/piper1-gpl)
voice, an `.onnx` file with its `.onnx.json` config, which goes to
`/data/speech/voice` and to `SPEECH_ARGS` as `--voice`: the backend speaks
answers with it, such as the weather (speech's `docs/backend-api.md#speech`).
Without one, it answers silently. Download one with speech's checkout:

```sh
(cd ../speech && uv run python -m piper.download_voices \
    --download-dir ../speech-os/models/voice en_US-kristin-medium)
```

Kristin's recordings are public domain, from LibriVox; other voices have
the licenses of theirs, see each voice's `MODEL_CARD` in
[rhasspy/piper-voices](https://huggingface.co/rhasspy/piper-voices). A
medium voice is 63 MB, and a Pi 4 synthesizes it about twice as fast as
it speaks.

## Wake word

`wake-word/` here holds at most one wake word model, an `.onnx` file of
speech's `examples/olivia/train.py`, which goes to `/data/speech/wake-word`
and to `SPEECH_ARGS` as `--wake-word`: the backend then starts a capture
when it hears "olivia", without a tap (speech's `examples/olivia/README.md`
and `docs/backend-api.md#wake-word`). Without one, captures start only from
the screen.

`vad/` holds at most one voice activity detector, Silero VAD's
`silero_vad.onnx` of version 5, which goes to `/data/speech/vad` and to
`SPEECH_ARGS` as `--vad`: the wake word model then runs only while someone
speaks, so music and noise do not set it off, and a capture ends when the
speech does. `sources` pins it, so CI fetches it:

```sh
curl -L -o models/vad/silero_vad.onnx --create-dirs \
    https://github.com/snakers4/silero-vad/raw/v5.1.2/src/silero_vad/data/silero_vad.onnx
```

## CI

CI downloads the models listed in `sources`, one per line as
`<sha256> <url> [path]`, saved as `models/<path>`, by default the url's
file name, and checks each against its hash. The acoustic model, the LM
and the wake word model are assets of this repository's `models-*`
release (a new set goes in a new release, so the old URLs keep working),
the voice is at a commit of rhasspy/piper-voices, and Silero VAD at its
tag. No songs are published, as they may be under copyright, so images
built by CI have none: a device plays songs once they are copied to
`/data/speech/songs`.

## On the device

The models live on `/data`, so they survive A/B updates and can be swapped
without a new image. Copy a new model over (`scp` on a dev image), edit
`SPEECH_ARGS` in `/data/etc/speech-backend`, and run
`systemctl restart speech-backend`.
