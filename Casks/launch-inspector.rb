cask "launch-inspector" do
  version "0.3.3"
  sha256 "a5f077148747189632baa2f034cde4ce4a06523130fa419dc0bf2b61d4150af1"

  url "https://github.com/vincentbattez/launchs-and-crons-inspector/releases/download/v#{version}/LaunchInspector-#{version}.dmg"
  name "LaunchInspector"
  desc "Lists your cron jobs and launchd plists, with state and schedule"
  homepage "https://github.com/vincentbattez/launchs-and-crons-inspector"

  auto_updates true # the app updates itself via Sparkle; Homebrew does not manage upgrades
  depends_on macos: :sonoma

  app "LaunchInspector.app"

  caveats <<~EOS
    LaunchInspector is an unsigned build. The first launch is blocked by Gatekeeper:
    open it once, then go to System Settings > Privacy & Security and click
    "Open Anyway" (on macOS 14 you can instead right-click the app > Open).
    After that it updates itself via Sparkle.
  EOS
end
