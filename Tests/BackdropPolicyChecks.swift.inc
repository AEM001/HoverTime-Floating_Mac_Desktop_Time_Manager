@main
struct BackdropPolicyChecks {
    static func main() {
        let start = Date(timeIntervalSince1970: 1000)
        var policy = BackdropPolicy()
        func time(_ seconds: Double) -> Date { start.addingTimeInterval(seconds) }
        // A single dark sample cannot flip the palette; persistence is required.
        assert(!policy.observe(luminance: 0.05, now: time(0), currentDark: false).dark)
        assert(!policy.observe(luminance: 0.05, now: time(45), currentDark: false).dark)
        assert(policy.observe(luminance: 0.05, now: time(90), currentDark: false).dark)
        // The deadband preserves either output rather than toggling at one threshold.
        policy.reset()
        assert(policy.observe(luminance: 0.25, now: time(100), currentDark: true).dark)
        var deadband = BackdropPolicy()
        assert(!deadband.observe(luminance: 0.25, now: time(0), currentDark: false).dark)
        // Moving resets the history, but must not bypass the three-minute dwell.
        policy.reset()
        assert(policy.observe(luminance: 0.8, now: time(110), currentDark: true).dark)
        assert(policy.observe(luminance: 0.8, now: time(180), currentDark: true).dark)
        assert(!policy.observe(luminance: 0.8, now: time(280), currentDark: true).dark)
        // Stable input backs off; a long visibility gap restarts confirmation.
        var stable = BackdropPolicy()
        _ = stable.observe(luminance: 0.8, now: time(0), currentDark: false)
        _ = stable.observe(luminance: 0.8, now: time(45), currentDark: false)
        assert(stable.observe(luminance: 0.8, now: time(90), currentDark: false).interval == 120)
        let resumed = stable.observe(luminance: 0.02, now: time(500), currentDark: false)
        assert(!resumed.dark && resumed.interval == 45)
        // Alternating boundary noise must not cause chatter.
        var noise = BackdropPolicy()
        var dark = false
        var switches = 0
        for i in 0..<40 {
            let decision = noise.observe(luminance: i.isMultiple(of: 2) ? 0.17 : 0.19,
                                         now: time(Double(i * 45)), currentDark: dark)
            if decision.dark != dark { switches += 1 }
            dark = decision.dark
        }
        assert(switches == 0)
        print("Backdrop policy: persistence, hysteresis, dwell, backoff, stale history and noise checks passed")
    }
}
