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

## How it works

A single binary is both the CLI and the menu bar app. `menunum run` puts an
`NSStatusItem` in the menu bar that hosts a SwiftUI view. Rolling digits use
`contentTransition(.numericText)`, tweening uses an `Animatable` view, and fading
uses an opacity/scale transition. Other commands send JSON to the running process
over `DistributedNotificationCenter`, and launch it first if needed.

## License

MIT
