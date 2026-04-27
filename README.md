# Beauty-R1 Clicker (macOS)

A small macOS menu-bar app that turns the **Beauty-R1** Bluetooth presentation clicker into arrow-key input.
Even when the device is not recognized as a keyboard, as long as it is visible as a HID, the up / down / left / right buttons are translated into the corresponding arrow keys and sent to the frontmost app (e.g. Marp in a browser).

## Install via Homebrew (Cask)

The repo doubles as a Homebrew tap. The cask pulls a prebuilt, ad-hoc-signed
`.app` from this repository's GitHub Releases and installs it into `/Applications`.

```bash
brew tap tnayuki/beauty-r1-clicker https://github.com/tnayuki/beauty-r1-clicker
brew install --cask beauty-r1-clicker
```

After install, launch from Launchpad / Spotlight / Finder. To uninstall:

```bash
brew uninstall --cask beauty-r1-clicker
brew untap tnayuki/beauty-r1-clicker
```

### Grant Accessibility

For synthetic key events to reach other apps, allow **`BeautyR1Clicker`** under
**System Settings → Privacy & Security → Accessibility** (and **Input Monitoring**
if needed).

## How it works

- Among all HIDs, only devices whose product name **contains `Beauty-R1`** (case-insensitive) are considered.
- A press on usagePage `0x0D` / usage `0x42` (tip-switch) starts a gesture. The X / Y carried in the same HID report are matched to the **nearest measured anchor** (one per direction) to decide which button was pressed.
- The corresponding virtual key is posted via `CGEvent`.

  | Button | Virtual key |
  | ------ | ----------- |
  | Up     | ↑           |
  | Down   | ↓           |
  | Left   | ←           |
  | Right  | →           |

- Real keyboards and mice are ignored entirely (only devices matching `Beauty-R1` are listened to), so there is no risk of feedback loops.
