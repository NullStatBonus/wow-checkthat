# Set up the tools

The plan and evidence tools (`tools/ct.py`, the `ct-test-plan` and `ct-verify` skills) are Python. They run the same on Windows, macOS and Linux. You do not need them to play the addon.

| What you want | You need |
| --- | --- |
| `validate`, `compile`, `collect`, `status`, `report`, `diff`, `trend`, `coverage`, `browse` | Python 3.9 or newer, with PyYAML and jsonschema |
| `replay`, `replay-flow`, `offline`, `drift` | The above, plus LuaJIT |
| `make test`, `make check` | The above, plus `make` (macOS, Linux or WSL on Windows) |

Install LuaJIT with `brew install luajit` (macOS), `sudo apt install luajit` (Debian, Ubuntu) or `scoop install luajit` (Windows). Other systems have it in their package manager. `ct.py doctor` ends with a tools section that says what is missing and how to install it.

With the plugin or the toolkit zip, and no checkout, `ct.py setup` creates the Python environment for you ([Plan skills](skills.md#install)). The steps below are for a checkout.

## 1. Install Python 3

- **Windows.** Run `winget install Python.Python.3.12` in a terminal, or use the installer from python.org and tick "Add python.exe to PATH". Open a new terminal afterwards. `py --version` must print a version.
- **macOS.** `brew install python`. The Xcode command line tools also give `python3`.
- **Linux.** `sudo apt install python3 python3-venv` (Debian, Ubuntu). Use your package manager elsewhere.

## 2. Create the environment

Run this in the repository folder.

| | Windows (PowerShell or cmd) | macOS and Linux |
| --- | --- | --- |
| Create | `py -m venv .venv` | `python3 -m venv .venv` |
| Install | `.venv\Scripts\python -m pip install -r requirements.txt` | `.venv/bin/python -m pip install -r requirements.txt` |
| Run | `.venv\Scripts\python tools\ct.py status` | `.venv/bin/python tools/ct.py status` |

Other pages write `.venv/bin/python`. On Windows read it as `.venv\Scripts\python`. The viewer needs `requirements-tui.txt` too (`browse`).

Run the Python tests without `make`: `.venv\Scripts\python -m unittest discover -s tools -p "test_*.py"`.

## 3. Read the game's saved variables

`/reload` or log out first, so the game writes the files. Then run `collect` on the PC that has the game:

```
.venv\Scripts\python tools\ct.py collect
```

With no flags, `collect` looks in the usual install places (run `ct.py doctor` to see where it looks and why it found nothing): `Program Files (x86)\World of Warcraft` and `Program Files\World of Warcraft` on Windows (drives C and D), `/Applications/World of Warcraft` on macOS, and the default Wine and Lutris prefixes on Linux. It prints the folder it uses. If your game is elsewhere, pass it once or save it:

```
.venv\Scripts\python tools\ct.py collect --wow "E:\Games\World of Warcraft"
```

```
# .ct.env (git-ignored) or ~/.checkthat.env
CT_WOW=E:\Games\World of Warcraft
```

## The game is on another computer

Copy the folders `_classic_era_\WTF`, `_forever_\WTF` and their `Screenshots` to the computer that has the tools, keeping the folder names, then point `--wow` at the copy. A network mount of the game folder works the same way. If screenshots go missing on a mount, see Screenshots in [Collect evidence](harvesting.md).
