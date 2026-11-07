@main
struct BackdropPolicyChecks {
    static func main() {
        precondition(BackdropPolicy.useLightInk(backgroundLuminance: 0))
        precondition(!BackdropPolicy.useLightInk(backgroundLuminance: 1))
        // Every sampled luminance must choose the higher-contrast color,
        // including gray where literal RGB inversion would disappear.
        for i in 0...1000 {
            let l = Double(i) / 1000
            let white = 1.05 / (l + 0.05)
            let black = (l + 0.05) / 0.05
            let light = BackdropPolicy.useLightInk(backgroundLuminance: l)
            let selected = light ? white : black
            precondition(selected >= (light ? black : white))
            precondition(selected >= 4.5)
        }
        // No previous sample or dwell time influences the next result.
        for l in [0.0, 1.0, 0.05, 0.8, 0.0] {
            precondition(BackdropPolicy.useLightInk(backgroundLuminance: l) == (l < 0.179128784747792))
        }
        print("Auto contrast: black/white choice maximizes contrast across 1001 luminance values; no history")
    }
}
