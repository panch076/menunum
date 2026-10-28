import Foundation
import MenuNumKit

let usage = """
menunum — animated numbers in your macOS menu bar

USAGE
  menunum set <number|-> [options]     Show a number (use - to read from stdin)
  menunum countdown <time> [options]   Count down, e.g. 90, 25:00, 1:30:00
  menunum stopwatch [options]          Count up from 0:00
  menunum pause | resume               Pause or resume a countdown/stopwatch
  menunum style <roll|tween|fade>      Change the animation style
  menunum clear                        Reset to the idle icon
  menunum quit                         Remove menunum from the menu bar
  menunum run                          Run the menu bar process in the foreground

OPTIONS
  -s, --style <roll|tween|fade>   roll: digits roll like the Clock timer (default)
                                  tween: counts from old value to new
                                  fade: cross-fades between values
  -d, --duration <seconds>        Animation length
  -p, --prefix <text>             Text shown before the number, e.g. "$"
  -x, --suffix <text>             Text shown after the number, e.g. "%"
      --decimals <n>              Decimal places (default: inferred from input)

The menu bar process starts automatically the first time you send a command.
"""

func fail(_ message: String) -> Never {
    FileHandle.standardError.write("menunum: \(message)\n".data(using: .utf8)!)
    exit(1)
}

/// Parses "90", "25:00" or "1:30:00" into seconds.
func parseTime(_ s: String) -> Double? {
    let parts = s.split(separator: ":").map { Double($0) }
    guard !parts.isEmpty, parts.count <= 3, parts.allSatisfy({ $0 != nil }) else { return nil }
    return parts.reduce(0) { $0 * 60 + $1! }
}

/// Parses a number and infers how many decimals the user wrote.
func parseNumber(_ s: String) -> (Double, Int)? {
    let cleaned = s.replacingOccurrences(of: ",", with: "")
    guard let v = Double(cleaned) else { return nil }
    let decimals = cleaned.split(separator: ".", omittingEmptySubsequences: false).dropFirst().first?.count ?? 0
    return (v, decimals)
}

func ensureRunning() {
    if IPC.runningPID() != nil { return }
    guard let exe = Bundle.main.executableURL else { fail("cannot locate own executable") }

    let p = Process()
    p.executableURL = exe
    p.arguments = ["run"]
    p.standardInput = FileHandle.nullDevice
    p.standardOutput = FileHandle.nullDevice
    p.standardError = FileHandle.nullDevice
    do { try p.run() } catch { fail("could not start menu bar process: \(error)") }

    for _ in 0..<50 {
        if IPC.runningPID() != nil { return }
        usleep(100_000)
    }
    fail("menu bar process did not start")
}

var args = Array(CommandLine.arguments.dropFirst())
guard let verb = args.first else { print(usage); exit(0) }
args.removeFirst()

var positional: [String] = []
var cmd = Command(action: .set)
var decimals: Int?

var i = 0
while i < args.count {
    let a = args[i]
    func next() -> String {
        i += 1
        guard i < args.count else { fail("\(a) needs a value") }
        return args[i]
    }
    switch a {
    case "-s", "--style":
        guard let s = AnimationStyle(rawValue: next()) else { fail("style must be roll, tween or fade") }
        cmd.style = s
    case "-d", "--duration":
        guard let d = Double(next()) else { fail("duration must be a number") }
        cmd.duration = d
    case "-p", "--prefix": cmd.prefix = next()
    case "-x", "--suffix": cmd.suffix = next()
    case "--decimals":
        guard let n = Int(next()), n >= 0 else { fail("decimals must be a non-negative integer") }
        decimals = n
    case "-h", "--help": print(usage); exit(0)
    default: positional.append(a)
    }
    i += 1
}

switch verb {
case "run":
    MainActor.assumeIsolated { MenuBarApp.run() }

case "set":
    guard var raw = positional.first else { fail("set needs a number") }
    if raw == "-" {
        raw = (readLine() ?? "").trimmingCharacters(in: .whitespaces)
    }
    guard let (v, inferred) = parseNumber(raw) else { fail("'\(raw)' is not a number") }
    cmd.action = .set
    cmd.value = v
    cmd.format = .number(decimals: decimals ?? inferred)

case "countdown":
    guard let raw = positional.first, let secs = parseTime(raw) else {
        fail("countdown needs a time like 90, 25:00 or 1:30:00")
    }
    cmd.action = .countdown
    cmd.value = secs

case "stopwatch": cmd.action = .stopwatch
case "pause": cmd.action = .pause
case "resume": cmd.action = .resume
case "clear": cmd.action = .clear

case "style":
    guard let raw = positional.first, let s = AnimationStyle(rawValue: raw) else {
        fail("style must be roll, tween or fade")
    }
    cmd.action = .style
    cmd.style = s

case "quit":
    if IPC.runningPID() != nil { IPC.send(Command(action: .quit)) }
    exit(0)

case "help", "-h", "--help":
    print(usage); exit(0)

default:
    fail("unknown command '\(verb)'. Run 'menunum help'.")
}

ensureRunning()
IPC.send(cmd)
