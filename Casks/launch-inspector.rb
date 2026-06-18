cask "launch-inspector" do
  version "0.3.2"
  sha256 "9275fea102e1f3d8411cd9cfa202c70d07a3b4d6f3f8f85b339d0cf1b2ba3c49"

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
