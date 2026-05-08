# frozen_string_literal: true

# Homebrew formula for auto-switch-mic.
#
# This file lives in the SOURCE repo for reference, but it must be COPIED into
# the tap repo (e.g. github.com/<you>/homebrew-tap/Formula/) to actually be
# usable via `brew install`. See docs/PUBLISHING.md for the workflow.
#
# Update procedure on each new release:
#   1. tag a new version on the source repo (e.g. v0.1.1)
#   2. compute the tarball sha256:
#        curl -sL https://github.com/<you>/auto-switch-mic/archive/refs/tags/v0.1.1.tar.gz | shasum -a 256
#   3. bump `url` and `sha256` below
#   4. commit + push to the tap repo
#   5. users get the update with `brew update && brew upgrade auto-switch-mic`

class AutoSwitchMic < Formula
  desc "macOS menu bar agent that auto-switches audio input to a preferred mic"
  homepage "https://github.com/vincentbattez/auto-switch-mic"
  url "https://github.com/vincentbattez/auto-switch-mic/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "e93d68629e353c61ec0e78630ba22ea9736623ecd076f7ab39cbd1538510beaf"
  license "MIT"
  head "https://github.com/vincentbattez/auto-switch-mic.git", branch: "main"

  depends_on :macos
  depends_on macos: :ventura # macOS 13+ required for SF Symbols configuration APIs in use
  depends_on xcode: ["14.0", :build]

  APP_BUNDLE_NAME = "Auto Switch Mic.app"

  def install
    # Compile both binaries from source. swiftc ships with Xcode CLT.
    system "swiftc", "-O", "toast.swift", "-o", "toast"
    system "swiftc", "-O", "auto-switch-mic.swift", "-o", "auto-switch-mic"

    # Build a minimal .app bundle so the agent is launchable from Spotlight,
    # Finder, or Launchpad (after the user symlinks it into /Applications/ —
    # see caveats). Contents/MacOS/ holds both binaries side-by-side, which is
    # exactly what the agent expects (it looks for `toast` next to its own path
    # via ProcessInfo.arguments[0].dirname).
    app = libexec/APP_BUNDLE_NAME
    macos_dir = app/"Contents/MacOS"
    macos_dir.mkpath
    (app/"Contents/Resources").mkpath

    cp "auto-switch-mic", macos_dir/"auto-switch-mic"
    cp "toast",            macos_dir/"toast"

    (app/"Contents/Info.plist").write info_plist_content

    # Ad-hoc sign so Gatekeeper accepts the bundle without an Apple Developer ID.
    system "/usr/bin/codesign", "--force", "--deep", "--sign", "-", app

    # Expose the agent as a CLI command in PATH (also used by `brew services`).
    bin.write_exec_script macos_dir/"auto-switch-mic"
  end

  service do
    run [opt_libexec/APP_BUNDLE_NAME/"Contents/MacOS/auto-switch-mic"]
    keep_alive successful_exit: false
    log_path var/"log/auto-switch-mic.log"
    error_log_path var/"log/auto-switch-mic.log"
    run_type :immediate
  end

  def caveats
    <<~EOS
      ▸ Auto-start at login (background service):
          brew services start auto-switch-mic

      ▸ Make it launchable from Spotlight (recommended):
          ln -sf "#{opt_libexec}/#{APP_BUNDLE_NAME}" /Applications/

        Then Cmd+Space → "Auto Switch Mic".

      ▸ Stop the service:
          brew services stop auto-switch-mic

      Logs: #{var}/log/auto-switch-mic.log
    EOS
  end

  def info_plist_content
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
          <key>CFBundleDisplayName</key>
          <string>Auto Switch Mic</string>
          <key>CFBundleName</key>
          <string>Auto Switch Mic</string>
          <key>CFBundleExecutable</key>
          <string>auto-switch-mic</string>
          <key>CFBundleIdentifier</key>
          <string>com.auto-switch-mic.app</string>
          <key>CFBundlePackageType</key>
          <string>APPL</string>
          <key>CFBundleShortVersionString</key>
          <string>#{version}</string>
          <key>CFBundleVersion</key>
          <string>#{version}</string>
          <key>LSMinimumSystemVersion</key>
          <string>13.0</string>
          <key>LSUIElement</key>
          <true/>
      </dict>
      </plist>
    XML
  end

  test do
    # Smoke tests: binaries exist as Mach-O and the .app structure is valid.
    macos_dir = libexec/APP_BUNDLE_NAME/"Contents/MacOS"
    assert_match(/Mach-O/, shell_output("file -b #{macos_dir}/auto-switch-mic"))
    assert_match(/Mach-O/, shell_output("file -b #{macos_dir}/toast"))
    assert_predicate libexec/APP_BUNDLE_NAME/"Contents/Info.plist", :exist?
    system "/usr/bin/codesign", "--verify", libexec/APP_BUNDLE_NAME
  end
end
