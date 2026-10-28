# menunum

Animated numbers in your macOS menu bar, driven from the command line.
Digits roll just like the Clock app's timer.

```sh
menunum countdown 25:00              # pomodoro
menunum set 1337 --style tween -p '$'  # count up to $1,337
menunum set 87.5 -x %                # rolls to 87.5%
```

## Install

Requires macOS 14+ and the Swift toolchain (Xcode or Command Line Tools).

```sh
git clone https://github.com/<you>/menunum.git
cd menunum
make install            # installs to /usr/local/bin (use PREFIX=~/.local to change)
```

## Usage

```
menunum set <number|-> [options]     Show a number (use - to read from stdin)
menunum countdown <time> [options]   Count down, e.g. 90, 25:00, 1:30:00
menunum stopwatch [options]          Count up from 0:00
menunum pause | resume               Pause or resume a countdown/stopwatch
menunum style <roll|tween|fade>      Change the animation style
menunum clear                        Reset to the idle icon
menunum quit                         Remove menunum from the menu bar
```

| Option | Description |
| --- | --- |
| `-s, --style roll\|tween\|fade` | Animation style (sticky until changed) |
| `-d, --duration <seconds>` | Animation length |
| `-p, --prefix <text>` | Text before the number, e.g. `$` |
| `-x, --suffix <text>` | Text after the number, e.g. `%` |
| `--decimals <n>` | Decimal places (inferred from input by default) |

The menu bar item starts automatically on the first command. Click it to
pause/restart timers, switch animation style, clear, or quit.

### Animation styles

- **roll** (default): each changed digit rolls up or down, like the Clock timer.
- **tween**: the value counts smoothly from the old number to the new one.
- **fade**: the old value fades and shrinks into the new one.

## Recipes

```sh
# Unread mail count every minute
while true; do menunum set "$(osascript -e 'tell app "Mail" to unread count of inbox')"; sleep 60; done

# Battery percentage
menunum set "$(pmset -g batt | grep -o '[0-9]*%' | tr -d %)" -x %

# Pipe in anything
curl -s https://api.coinbase.com/v2/prices/BTC-USD/spot | jq -r .data.amount | menunum set - -s tween -p '$' --decimals 0
```

### Start at login

Add `menunum run` to a LaunchAgent, or just add any `menunum` command to your shell
startup. The menu bar process starts on first use either way.

## Use it in your own app

The animation lives in **MenuNumKit**, a Swift package library you can drop into any
macOS 14+ app. In Xcode: *File → Add Package Dependencies…* and paste this repo's URL,
or in `Package.swift`:

```swift
.package(url: "https://github.com/<you>/menunum.git", branch: "main")
// ...
.target(name: "MyApp", dependencies: [.product(name: "MenuNumKit", package: "menunum")])
```

### A ready-made menu bar item (AppKit)

```swift
import MenuNumKit

let item = AnimatedStatusItem()        // keep a strong reference
item.menu = myMenu                     // optional click menu

item.number.style = .roll              // .roll, .tween or .fade
item.number.prefix = "$"
item.number.set(1337)                  // animates to $1,337
item.number.countdown(from: 25 * 60)   // 25:00 ticking down
item.number.onCountdownFinished = { NSSound.beep() }
```

`AnimatedNumber` is an `ObservableObject`, so you can also drive it from SwiftUI state.
It supports `set`, `countdown`, `stopwatch`, `pause`, `resume`, `restart` and `clear`.

### Just the view (SwiftUI)

`AnimatedNumberText` animates whenever its value changes, wherever you put it:

```swift
MenuBarExtra {
    Button("Add") { count += 1 }
} label: {
    AnimatedNumberText(value: count, style: .roll)
}

// or anywhere else
AnimatedNumberText(value: price, style: .tween, format: .number(decimals: 2), prefix: "$")
    .font(.largeTitle)
```

`AnimatedStatusItem` exists because `MenuBarExtra` labels don't always animate
reliably. If you see that, use the status item instead.

A complete example is in [`Examples/Demo`](Examples/Demo/main.swift): `swift run menunum-demo`.

## How it works

- **MenuNumKit** (`Sources/MenuNumKit`) has the reusable pieces. `AnimatedNumberText` uses
  `contentTransition(.numericText)` for rolling, an `Animatable` view for tweening and an
  opacity/scale transition for fading. `AnimatedStatusItem` hosts that view inside an
  `NSStatusItem` and resizes it to fit.
- **menunum** (`Sources/menunum`) is a thin CLI on top. `menunum run` shows an
  `AnimatedStatusItem`. Other commands send JSON to that process over
  `DistributedNotificationCenter`, launching it first if needed.

Run the tests with `swift test`.

## License

MIT
