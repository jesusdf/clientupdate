#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
mkvdef - Set the default audio and subtitle tracks of MKV files by language.

- No remuxing: only the container headers are rewritten with `mkvpropedit`,
  so the operation is instant and the streams are untouched.
- Tracks are selected by LANGUAGE (BCP-47 / ISO-639), never by index or name,
  so the same preference works across files with different track layouts.
- The last choice is remembered in ~/.config/mkvdef/config.json.
- --auto applies without prompting, using CLI values or the remembered ones.
- If "es-ES" is requested but missing, the best "es-*" match is used instead.

Requires: mkvtoolnix (mkvmerge + mkvpropedit) and Python 3.7+.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

APP = "mkvdef"
VERSION = "1.0"

# Track names may contain non-ASCII characters; on ASCII-only terminals a
# plain print() would raise UnicodeEncodeError, so degrade gracefully instead.
for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(errors="replace")
    except (AttributeError, ValueError):
        pass

NONE_WORDS = {"none", "no", "off", "-"}

# ISO 639-2/B and 639-2/T to ISO 639-1, so that "spa" and "es" compare equal.
# Matroska files commonly store the legacy 3-letter code while users type the
# 2-letter one (or vice versa).
ISO3_TO_ISO1 = {
    "spa": "es", "eng": "en", "fre": "fr", "fra": "fr", "ger": "de", "deu": "de",
    "ita": "it", "por": "pt", "cat": "ca", "baq": "eu", "eus": "eu", "glg": "gl",
    "jpn": "ja", "chi": "zh", "zho": "zh", "kor": "ko", "rus": "ru", "ara": "ar",
    "dut": "nl", "nld": "nl", "swe": "sv", "nor": "no", "dan": "da", "fin": "fi",
    "pol": "pl", "cze": "cs", "ces": "cs", "slo": "sk", "slk": "sk", "hun": "hu",
    "tur": "tr", "gre": "el", "ell": "el", "heb": "he", "hin": "hi", "tha": "th",
    "vie": "vi", "ind": "id", "may": "ms", "msa": "ms", "ukr": "uk", "rum": "ro",
    "ron": "ro", "bul": "bg", "hrv": "hr", "srp": "sr", "slv": "sl", "est": "et",
    "lav": "lv", "lit": "lt", "ice": "is", "isl": "is", "gle": "ga", "fil": "tl",
    "tgl": "tl", "per": "fa", "fas": "fa", "ben": "bn", "tam": "ta", "tel": "te",
    "urd": "ur", "mal": "ml", "mar": "mr", "guj": "gu", "kan": "kn", "pan": "pa",
}


# --------------------------------------------------------------------------- #
# Language helpers
# --------------------------------------------------------------------------- #
def norm_lang(code: str) -> str:
    """Normalize 'es_ES', 'spa', 'ES-es' -> 'es-es'."""
    if not code:
        return ""
    parts = [p for p in code.strip().lower().replace("_", "-").split("-") if p]
    if not parts:
        return ""
    parts[0] = ISO3_TO_ISO1.get(parts[0], parts[0])
    return "-".join(parts)


def lang_score(track_lang: str, wanted: str):
    """
    Score how well `track_lang` satisfies `wanted`; None if the base
    languages differ.

        wanted es-es  ->  es-es : 200   (exact)
                          es    : 100   (generic)
                          es-mx :  90   (same family, other region)
                          en-us : None
    """
    t = track_lang.split("-")
    w = wanted.split("-")
    if not t[0] or t[0] != w[0]:
        return None
    common = 0
    for a, b in zip(t, w):
        if a != b:
            break
        common += 1
    # Penalize extra subtags so the generic "es" outranks "es-mx" when the
    # user asked for "es-es": fewer wrong assumptions.
    extra = len(t) - common
    return common * 100 - extra * 10


# --------------------------------------------------------------------------- #
# Model
# --------------------------------------------------------------------------- #
class Track:
    __slots__ = ("num", "uid", "kind", "lang", "name", "codec", "default",
                 "forced", "enabled", "idx")

    def __init__(self, num, uid, kind, lang, name, codec, default, forced,
                 enabled, idx):
        self.num = num
        self.uid = uid
        self.kind = kind          # 'audio' | 'subtitles' | 'video'
        self.lang = lang          # normalized
        self.name = name
        self.codec = codec
        self.default = default
        self.forced = forced
        self.enabled = enabled
        self.idx = idx            # 1..N within its kind

    @property
    def selector(self) -> str:
        """mkvpropedit selector; the UID is stable even if tracks reorder."""
        if self.uid:
            return "track:=%d" % self.uid
        return "track:@%d" % self.num

    def describe(self) -> str:
        marks = []
        if self.default:
            marks.append("default")
        if self.forced:
            marks.append("forced")
        if not self.enabled:
            marks.append("disabled")
        extra = (" [%s]" % ", ".join(marks)) if marks else ""
        name = ' "%s"' % self.name if self.name else ""
        return "%-8s %-12s%s%s" % (self.lang or "und", self.codec, name, extra)


def die(msg: str, code: int = 1):
    print("%s: error: %s" % (APP, msg), file=sys.stderr)
    sys.exit(code)


def run_tool(cmd):
    """
    Run mkvmerge/mkvpropedit in a locale-independent way.

    mkvmerge -J always emits UTF-8, but subprocess with text=True decodes
    using the user's locale, which silently corrupts non-ASCII track names
    under LANG=C or legacy locales (or raises UnicodeDecodeError). Forcing
    the child's locale also keeps its diagnostics deterministic (English).
    """
    env = dict(os.environ, LC_ALL="C.UTF-8", LANG="C.UTF-8", LANGUAGE="")
    return subprocess.run(cmd, capture_output=True,
                          encoding="utf-8", errors="replace", env=env)


def need_tools():
    missing = [t for t in ("mkvmerge", "mkvpropedit") if not shutil.which(t)]
    if missing:
        die("%s not found. Install mkvtoolnix." % " and ".join(missing))


def identify(path: Path):
    """Read the track list via `mkvmerge -J`."""
    try:
        res = run_tool(["mkvmerge", "-J", str(path)])
    except OSError as e:
        die("could not run mkvmerge: %s" % e)
    # mkvmerge exit codes: 0 = ok, 1 = warnings, 2 = error.
    if res.returncode >= 2:
        die("mkvmerge could not read %s:\n%s" % (path, res.stderr.strip()))
    try:
        data = json.loads(res.stdout)
    except ValueError:
        die("invalid mkvmerge output for %s" % path)

    tracks, counters = [], {}
    for t in data.get("tracks", []):
        p = t.get("properties", {}) or {}
        kind = t.get("type", "")
        # Prefer the IETF/BCP-47 tag (may carry a region, e.g. es-MX); fall
        # back to the legacy 3-letter field when it is absent or "und".
        ietf = (p.get("language_ietf") or "").strip()
        legacy = (p.get("language") or "und").strip()
        lang = norm_lang(ietf) if ietf and ietf.lower() != "und" else norm_lang(legacy)
        counters[kind] = counters.get(kind, 0) + 1
        tracks.append(Track(
            num=p.get("number", 0),
            uid=p.get("uid", 0) or 0,
            kind=kind,
            lang=lang,
            name=(p.get("track_name") or "").strip(),
            codec=t.get("codec", "?"),
            default=bool(p.get("default_track", False)),
            forced=bool(p.get("forced_track", False)),
            enabled=bool(p.get("enabled_track", True)),
            idx=counters[kind],
        ))
    return tracks


def pick(tracks, wanted: str):
    """Best track for the requested language, or None."""
    best, best_key = None, None
    for t in tracks:
        s = lang_score(t.lang, wanted)
        if s is None:
            continue
        # Tie-breakers: forced subtitles are usually partial (signs/songs),
        # so prefer non-forced ones; then the current default; then file order.
        key = (s,
               1 if (t.kind == "subtitles" and not t.forced) else 0,
               1 if t.default else 0,
               -t.idx)
        if best_key is None or key > best_key:
            best, best_key = t, key
    return best


# --------------------------------------------------------------------------- #
# Persistent configuration
# --------------------------------------------------------------------------- #
def config_path(custom=None) -> Path:
    if custom:
        return Path(custom).expanduser()
    base = os.environ.get("XDG_CONFIG_HOME") or (Path.home() / ".config")
    return Path(base) / APP / "config.json"


def load_config(path: Path) -> dict:
    try:
        with path.open(encoding="utf-8") as fh:
            data = json.load(fh)
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        # Missing or corrupt config is not fatal; start fresh.
        return {}


def save_config(path: Path, cfg: dict):
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        # Write-then-rename so a crash cannot leave a truncated config.
        tmp = path.with_suffix(".tmp")
        with tmp.open("w", encoding="utf-8") as fh:
            json.dump(cfg, fh, indent=2, ensure_ascii=False)
            fh.write("\n")
        tmp.replace(path)
    except OSError as e:
        print("%s: warning: could not save configuration (%s)" % (APP, e),
              file=sys.stderr)


# --------------------------------------------------------------------------- #
# Display / interaction
# --------------------------------------------------------------------------- #
def show_tracks(path: Path, tracks):
    print("\n== %s" % path.name)
    for kind, title in (("audio", "Audio"), ("subtitles", "Subtitles")):
        sel = [t for t in tracks if t.kind == kind]
        if not sel:
            print("  %s: (none)" % title)
            continue
        print("  %s:" % title)
        for t in sel:
            print("    %2d) %s" % (t.idx, t.describe()))


def ask(kind_title, tracks, current_pref, allow_none):
    """Interactive menu. Returns a Track, 'none', or None (keep as is)."""
    if not tracks:
        return None
    print("\n  Available %s:" % kind_title.lower())
    for t in tracks:
        star = "*" if t.default else " "
        print("   %s%2d) %s" % (star, t.idx, t.describe()))
    if allow_none:
        print("     0) none (disable subtitles)")
    hint = " [remembered: %s]" % current_pref if current_pref else ""
    print("     ENTER = keep as is%s" % hint)

    valid = {str(t.idx): t for t in tracks}
    while True:
        try:
            raw = input("  Choose %s: " % kind_title.lower()).strip()
        except (EOFError, KeyboardInterrupt):
            print()
            return None
        if raw == "":
            return None
        if raw.lower() in NONE_WORDS and allow_none:
            return "none"
        if raw in valid:
            return valid[raw]
        print("  Invalid option.")


# --------------------------------------------------------------------------- #
# Applying changes
# --------------------------------------------------------------------------- #
def build_edits(tracks, kind, chosen):
    """
    Build mkvpropedit arguments for one track kind.

    chosen: Track (mark it default), 'none' (clear all), or None (don't touch).
    Every other track of the same kind gets flag-default=0, which also cleans
    up files that ship with several defaults set. Only actual changes are
    emitted so an already-correct file produces no edits at all.
    """
    args = []
    if chosen is None:
        return args
    for t in (x for x in tracks if x.kind == kind):
        want = not isinstance(chosen, str) and chosen is t
        if t.default != want:
            args += ["--edit", t.selector, "--set", "flag-default=%d" % want]
    return args


def resolve(tracks, kind, wanted, path):
    """Map a requested language to a concrete track."""
    if wanted is None:
        return None
    if wanted == "none":
        return "none"
    cand = [t for t in tracks if t.kind == kind]
    if not cand:
        print("  warning: %s has no %s tracks" % (path.name, kind))
        return None
    t = pick(cand, wanted)
    if t is None:
        print("  warning: no %s in '%s' (available: %s); left unchanged"
              % (kind, wanted, ", ".join(sorted({c.lang or "und" for c in cand}))))
        return None
    if t.lang != wanted:
        print("  note: '%s' not found; using '%s'" % (wanted, t.lang))
    return t


def process(path: Path, want_audio, want_subs, dry_run):
    tracks = identify(path)
    a = resolve(tracks, "audio", want_audio, path)
    s = resolve(tracks, "subtitles", want_subs, path)

    edits = build_edits(tracks, "audio", a) + build_edits(tracks, "subtitles", s)
    if not edits:
        print("  no changes (already as requested)")
        return True

    cmd = ["mkvpropedit", str(path)] + edits
    if dry_run:
        print("  [dry-run] " + " ".join(cmd))
        return True

    res = run_tool(cmd)
    if res.returncode >= 2:
        print("  mkvpropedit error: %s" % (res.stderr.strip() or res.stdout.strip()),
              file=sys.stderr)
        return False

    def label(x):
        if x == "none":
            return "none"
        return "%s%s" % (x.lang or "und", ' "%s"' % x.name if x.name else "")

    parts = []
    if a is not None:
        parts.append("audio -> %s" % label(a))
    if s is not None:
        parts.append("subs -> %s" % label(s))
    print("  OK: " + "; ".join(parts))
    return True


# --------------------------------------------------------------------------- #
# Graphical interface (tkinter, no external dependencies)
# --------------------------------------------------------------------------- #
def run_gui(paths, cfg_file, cfg):
    # Imported lazily so the CLI keeps working on systems without python3-tk.
    try:
        import tkinter as tk
        from tkinter import filedialog, messagebox, ttk
    except ImportError:
        die("tkinter is not available; install python3-tk or use the CLI")

    need_tools()

    root = tk.Tk()
    root.title("%s %s - default audio/subtitles" % (APP, VERSION))
    root.minsize(760, 460)

    files = []            # [{'path': Path, 'tracks': [Track]}]
    audio_var = tk.IntVar(value=-1)   # index into audio tracks, -1 = keep
    subs_var = tk.IntVar(value=-2)    # -1 = none, -2 = keep
    remember = tk.BooleanVar(value=True)

    # ---- layout -----------------------------------------------------------
    top = ttk.Frame(root, padding=6); top.pack(fill="x")
    ttk.Button(top, text="Add files...",
               command=lambda: add_files()).pack(side="left")
    ttk.Button(top, text="Remove", command=lambda: remove_sel()).pack(
        side="left", padx=(6, 0))
    ttk.Button(top, text="Apply remembered to ALL",
               command=lambda: apply_all()).pack(side="right")

    body = ttk.Panedwindow(root, orient="horizontal")
    body.pack(fill="both", expand=True, padx=6, pady=(0, 6))

    left = ttk.Frame(body); body.add(left, weight=1)
    ttk.Label(left, text="Files").pack(anchor="w")
    lb = tk.Listbox(left, exportselection=False)
    lb.pack(fill="both", expand=True)

    right = ttk.Frame(body); body.add(right, weight=2)
    fr_a = ttk.Labelframe(right, text="Default audio", padding=6)
    fr_a.pack(fill="both", expand=True)
    fr_s = ttk.Labelframe(right, text="Default subtitle", padding=6)
    fr_s.pack(fill="both", expand=True, pady=(6, 0))

    bottom = ttk.Frame(root, padding=6); bottom.pack(fill="x")
    ttk.Checkbutton(bottom, text="Remember choice (by language)",
                    variable=remember).pack(side="left")
    ttk.Button(bottom, text="Apply to selected file",
               command=lambda: apply_current()).pack(side="right")
    status = ttk.Label(root, relief="sunken", anchor="w", padding=(6, 2))
    status.pack(fill="x", side="bottom")

    def say(msg):
        status.config(text=msg)
        root.update_idletasks()

    # ---- logic ------------------------------------------------------------
    def current():
        sel = lb.curselection()
        return files[sel[0]] if sel else None

    def add_paths(new_paths):
        for pth in new_paths:
            pth = Path(pth)
            if not pth.is_file():
                say("not found: %s" % pth)
                continue
            if any(f["path"] == pth for f in files):
                continue
            try:
                files.append({"path": pth, "tracks": identify(pth)})
                lb.insert("end", pth.name)
            except SystemExit:
                # identify() calls die() on unreadable files; in the GUI that
                # must not kill the whole application.
                messagebox.showerror(APP, "Could not read %s" % pth)
        if files and not lb.curselection():
            lb.selection_set(0)
            refresh()

    def add_files():
        chosen = filedialog.askopenfilenames(
            title="Choose MKV files",
            filetypes=[("Matroska", "*.mkv *.mka *.mks"), ("All files", "*")])
        add_paths(chosen)

    def remove_sel():
        sel = lb.curselection()
        if sel:
            lb.delete(sel[0])
            files.pop(sel[0])
            refresh()

    def clear(frame):
        for w in frame.winfo_children():
            w.destroy()

    def refresh(*_):
        clear(fr_a); clear(fr_s)
        f = current()
        if not f:
            ttk.Label(fr_a, text="(choose a file)").pack(anchor="w")
            return
        f["tracks"] = identify(f["path"])  # re-read in case it changed on disk
        atr = [t for t in f["tracks"] if t.kind == "audio"]
        strk = [t for t in f["tracks"] if t.kind == "subtitles"]

        def prefill(var, tracks, saved, none_val):
            # Preselection priority: remembered language > current default
            # track > keep as is.
            if saved == "none" and none_val is not None:
                var.set(none_val); return
            t = pick(tracks, saved) if saved else None
            if t is None:
                t = next((x for x in tracks if x.default), None)
            var.set(tracks.index(t) if t in tracks else (-2 if none_val else -1))

        ttk.Radiobutton(fr_a, text="(keep as is)", value=-1,
                        variable=audio_var).pack(anchor="w")
        for i, t in enumerate(atr):
            ttk.Radiobutton(fr_a, text=t.describe(), value=i,
                            variable=audio_var).pack(anchor="w")
        if not atr:
            ttk.Label(fr_a, text="(no audio tracks)").pack(anchor="w")

        ttk.Radiobutton(fr_s, text="(keep as is)", value=-2,
                        variable=subs_var).pack(anchor="w")
        ttk.Radiobutton(fr_s, text="None (disable subtitles)", value=-1,
                        variable=subs_var).pack(anchor="w")
        for i, t in enumerate(strk):
            ttk.Radiobutton(fr_s, text=t.describe(), value=i,
                            variable=subs_var).pack(anchor="w")
        if not strk:
            ttk.Label(fr_s, text="(no subtitle tracks)").pack(anchor="w")

        prefill(audio_var, atr, cfg.get("audio"), None)
        prefill(subs_var, strk, cfg.get("subtitles"), -1)
        say("%s | audio: %d track(s), subs: %d" %
            (f["path"].name, len(atr), len(strk)))

    def do_apply(f, want_audio, want_subs):
        return process(f["path"], want_audio, want_subs, dry_run=False)

    def maybe_save(want_audio, want_subs):
        if not remember.get():
            return
        changed = False
        for key, val in (("audio", want_audio), ("subtitles", want_subs)):
            if val is not None and cfg.get(key) != val:
                cfg[key] = val; changed = True
        if changed:
            save_config(cfg_file, cfg)

    def apply_current():
        f = current()
        if not f:
            messagebox.showinfo(APP, "Choose a file from the list")
            return
        atr = [t for t in f["tracks"] if t.kind == "audio"]
        strk = [t for t in f["tracks"] if t.kind == "subtitles"]
        ai, si = audio_var.get(), subs_var.get()
        # The preference is stored as the chosen track's LANGUAGE, not its
        # index, so it transfers to files with a different track order.
        want_audio = atr[ai].lang if 0 <= ai < len(atr) else None
        want_subs = ("none" if si == -1 else
                     strk[si].lang if 0 <= si < len(strk) else None)
        if want_audio is None and want_subs is None:
            say("nothing to change")
            return
        say("applying to %s ..." % f["path"].name)
        if do_apply(f, want_audio, want_subs):
            maybe_save(want_audio, want_subs)
            refresh()
            say("done: %s" % f["path"].name)
        else:
            messagebox.showerror(APP, "mkvpropedit failed on %s" % f["path"].name)

    def apply_all():
        want_audio, want_subs = cfg.get("audio"), cfg.get("subtitles")
        if want_audio is None and want_subs is None:
            messagebox.showinfo(
                APP, "No remembered preferences yet.\n"
                     "Apply to one file first with 'Remember' checked.")
            return
        if not files:
            messagebox.showinfo(APP, "Add files first")
            return
        fails = 0
        for f in files:
            say("applying to %s ..." % f["path"].name)
            if not do_apply(f, want_audio, want_subs):
                fails += 1
        refresh()
        say("finished: %d file(s), %d failure(s)" % (len(files), fails))

    lb.bind("<<ListboxSelect>>", refresh)
    add_paths(paths)
    refresh()
    root.mainloop()
    return 0


# --------------------------------------------------------------------------- #
# main
# --------------------------------------------------------------------------- #
def main(argv=None):
    p = argparse.ArgumentParser(
        prog=APP,
        formatter_class=argparse.RawDescriptionHelpFormatter,
        description="""Set which AUDIO track and which SUBTITLE track are
flagged as "default" in MKV files, selecting them by LANGUAGE.

No remuxing: only the container headers are rewritten with `mkvpropedit`,
so the operation is instant and neither video nor audio is altered.""",
        epilog="""MODES
  Interactive (no -y and no -a/-s): shows the file's tracks and asks which
    audio and subtitle you want. The choice is remembered.
  Automatic (-y/--auto): no prompts. Uses the languages given with -a/-s
    and falls back to the last-used ones for anything omitted. Ideal for
    batches: mkvdef -y /path/to/show/*.mkv
  Query only (-l/--list): lists the tracks and changes nothing.
  Graphical (-g/--gui): tkinter window with the file list and each file's
    tracks as radio buttons. Preselects from the remembered languages,
    can apply to the current file or the remembered choice to all files
    in batch, and saves the choice by language just like the CLI.
    Requires python3-tk.

LANGUAGES
  Accepted formats, all equivalent: es, es-ES, es_ES, ES_es, spa.
  ISO 639-2 codes (spa, eng, ger, fre...) are mapped to ISO 639-1.
  If the requested language is not present verbatim, the best match from
  the same family is used, in this order:
      requested es-ES  ->  1. es-ES  (exact match)
                           2. es     (generic)
                           3. es-419 / es-MX / es-AR ... (other region)
  If no track of that family exists, a warning is printed and the flag is
  left untouched (nothing is changed by mistake).
  Among tied candidates, non-forced subtitles are preferred.
  For subtitles, the value 'none' (also: no, off, -) clears the default
  flag on every subtitle track.

REMEMBERED PREFERENCES
  The chosen LANGUAGE (never the track index or name) is stored in
  ~/.config/mkvdef/config.json  (or $XDG_CONFIG_HOME/mkvdef/config.json),
  so the same preference works on files with a different track order.
  Change the path with --config, skip saving with --no-save, inspect it
  with --show-config, and delete it with --forget.

EXIT CODES
  0 = success   1 = some file failed or was missing   130 = interrupted

REQUIREMENTS
  Python 3.7+ and mkvtoolnix (mkvmerge and mkvpropedit on PATH).

EXAMPLES
  %(prog)s movie.mkv                    interactive menu (remembers choice)
  %(prog)s -y *.mkv                     apply last-used, no prompts
  %(prog)s -y -a es-ES -s en show.mkv   force languages and remember them
  %(prog)s -y -a es -s none *.mkv       Spanish audio, subtitles off
  %(prog)s -y -a jpn -s es-ES anime/    (with shell globbing: anime/*.mkv)
  %(prog)s -n -y -a es *.mkv            dry run: print the mkvpropedit call
  %(prog)s -l movie.mkv                 list tracks only
  %(prog)s --show-config                show saved preferences""")
    p.add_argument("files", nargs="*", type=Path,
                   help="one or more .mkv files to process")
    p.add_argument("-a", "--audio", metavar="LANG",
                   help="desired audio language (es, es-ES, es_ES, spa...); "
                        "if absent, the best same-family match is used")
    p.add_argument("-s", "--subs", "--subtitles", metavar="LANG",
                   help="desired subtitle language; use 'none' (or no, off, "
                        "-) to disable all subtitles")
    p.add_argument("-y", "--auto", action="store_true",
                   help="apply without prompting: uses -a/-s and, for "
                        "anything omitted, the saved preferences")
    p.add_argument("-l", "--list", action="store_true",
                   help="only show each file's tracks and exit, changing "
                        "nothing")
    p.add_argument("-n", "--dry-run", action="store_true",
                   help="print the mkvpropedit command that would run, "
                        "without touching the files or the config")
    p.add_argument("--no-save", action="store_true",
                   help="apply the changes but do not store the chosen "
                        "languages as the preference")
    p.add_argument("--config", metavar="PATH",
                   help="use a different configuration file "
                        "(default: ~/.config/mkvdef/config.json)")
    p.add_argument("--show-config", action="store_true",
                   help="print the path and content of the saved "
                        "preferences, then exit")
    p.add_argument("-g", "--gui", action="store_true",
                   help="open the graphical interface (tkinter); any files "
                        "given are preloaded into the list")
    p.add_argument("--forget", action="store_true",
                   help="delete the saved preferences file and exit")
    p.add_argument("-V", "--version", action="version",
                   version="%(prog)s " + VERSION)
    args = p.parse_args(argv)

    cfg_file = config_path(args.config)
    cfg = load_config(cfg_file)

    if args.show_config:
        print("config: %s" % cfg_file)
        print("  audio    : %s" % (cfg.get("audio") or "(not set)"))
        print("  subtitles: %s" % (cfg.get("subtitles") or "(not set)"))
        return 0

    if args.forget:
        try:
            cfg_file.unlink()
            print("preferences deleted (%s)" % cfg_file)
        except OSError:
            print("no preferences to delete")
        return 0

    if args.gui:
        return run_gui(args.files, cfg_file, cfg)

    if not args.files:
        p.error("give at least one .mkv file (or use --gui)")

    need_tools()

    def parse_pref(v):
        if v is None:
            return None
        return "none" if v.strip().lower() in NONE_WORDS else norm_lang(v)

    cli_audio = parse_pref(args.audio)
    cli_subs = parse_pref(args.subs)

    if args.auto:
        # CLI values win; the saved preference only fills the gaps.
        want_audio = cli_audio if cli_audio is not None else cfg.get("audio")
        want_subs = cli_subs if cli_subs is not None else cfg.get("subtitles")
        if want_audio is None and want_subs is None:
            die("--auto with no saved preferences: use -a/-s the first time")
    else:
        want_audio, want_subs = cli_audio, cli_subs

    interactive = not args.auto and not args.list and \
        (want_audio is None and want_subs is None)
    if interactive and not sys.stdin.isatty():
        die("no interactive terminal; use --auto or -a/-s")

    rc = 0
    for path in args.files:
        if not path.is_file():
            print("%s: warning: no such file %s" % (APP, path), file=sys.stderr)
            rc = 1
            continue

        tracks = identify(path)
        show_tracks(path, tracks)
        if args.list:
            continue

        a_want, s_want = want_audio, want_subs
        if interactive:
            ca = ask("Audio", [t for t in tracks if t.kind == "audio"],
                     cfg.get("audio"), allow_none=False)
            cs = ask("Subtitles", [t for t in tracks if t.kind == "subtitles"],
                     cfg.get("subtitles"), allow_none=True)
            a_want = ca.lang if isinstance(ca, Track) else (ca or None)
            s_want = cs.lang if isinstance(cs, Track) else (cs or None)
            if a_want is None and s_want is None:
                print("  no changes")
                continue

        if not process(path, a_want, s_want, args.dry_run):
            rc = 1
            continue

        if not args.no_save and not args.dry_run:
            changed = False
            if a_want is not None and cfg.get("audio") != a_want:
                cfg["audio"] = a_want
                changed = True
            if s_want is not None and cfg.get("subtitles") != s_want:
                cfg["subtitles"] = s_want
                changed = True
            if changed:
                save_config(cfg_file, cfg)

    return rc


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
