# frozen_string_literal: true

# Homebrew formula for auto-switch-in-out-menubar.
#
# This file lives in the SOURCE repo for reference, but it must be COPIED into
# the tap repo (e.g. github.com/<you>/homebrew-tap/Formula/) to actually be
# usable via `brew install`. See docs/PUBLISHING.md for the workflow.
#
# Update procedure on each new release:
#   1. tag a new version on the source repo (e.g. v0.1.1)
#   2. compute the tarball sha256:
#        curl -sL https://github.com/<you>/auto-switch-in-out-menubar/archive/refs/tags/v0.1.1.tar.gz | shasum -a 256
#   3. bump `url` and `sha256` below
#   4. commit + push to the tap repo
#   5. users get the update with `brew update && brew upgrade auto-switch-in-out-menubar`

class AutoSwitchInOutMenubar < Formula
  desc "macOS menu bar agent that auto-switches audio input to a preferred mic"
  homepage "https://github.com/vincentbattez/auto-switch-in-out-menubar"
  url "https://github.com/vincentbattez/auto-switch-in-out-menubar/archive/refs/tags/v0.2.0.tar.gz"
  sha256 "05fc8dc0d29c72bdb44b565edf3909fbd61c109ba98182bb47a7ea5aea2613eb"
  license "MIT"
  head "https://github.com/vincentbattez/auto-switch-in-out-menubar.git", branch: "main"

  depends_on :macos
  depends_on macos: :ventura # macOS 13+ required for SF Symbols configuration APIs in use
  depends_on xcode: ["14.0", :build]

  APP_BUNDLE_NAME = "Auto Switch In Out.app"

  def install
    # Compile both binaries from source. swiftc ships with Xcode CLT.
    system "swiftc", "-O", "toast.swift", "-o", "toast"
    system "swiftc", "-O", "auto-switch-in-out-menubar.swift", "-o", "auto-switch-in-out-menubar"

    # Build a minimal .app bundle so the agent is launchable from Spotlight,
    # Finder, or Launchpad (after the user symlinks it into /Applications/ —
    # see caveats). Contents/MacOS/ holds both binaries side-by-side, which is
    # exactly what the agent expects (it looks for `toast` next to its own path
    # via ProcessInfo.arguments[0].dirname).
    app = libexec/APP_BUNDLE_NAME
    macos_dir = app/"Contents/MacOS"
    macos_dir.mkpath
    (app/"Contents/Resources").mkpath

    cp "auto-switch-in-out-menubar", macos_dir/"auto-switch-in-out-menubar"
    cp "toast",            macos_dir/"toast"

    (app/"Contents/Info.plist").write info_plist_content

    # Ad-hoc sign so Gatekeeper accepts the bundle without an Apple Developer ID.
    system "/usr/bin/codesign", "--force", "--deep", "--sign", "-", app

    # Expose the agent as a CLI command in PATH (also used by `brew services`).
    bin.write_exec_script macos_dir/"auto-switch-in-out-menubar"
  end

  service do
    run [opt_libexec/APP_BUNDLE_NAME/"Contents/MacOS/auto-switch-in-out-menubar"]
    keep_alive successful_exit: false
    log_path var/"log/auto-switch-in-out-menubar.log"
    error_log_path var/"log/auto-switch-in-out-menubar.log"
    run_type :immediate
  end

  def caveats
    <<~EOS
      ▸ Auto-start at login (background service):
          brew services start auto-switch-in-out-menubar

      ▸ Make it launchable from Spotlight (recommended):
          ln -sf "#{opt_libexec}/#{APP_BUNDLE_NAME}" /Applications/

        Then Cmd+Space → "Auto Switch In Out".

      ▸ Stop the service:
          brew services stop auto-switch-in-out-menubar

      Logs: #{var}/log/auto-switch-in-out-menubar.log
    EOS
  end

  def info_plist_content
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
          <key>CFBundleDisplayName</key>
          <string>Auto Switch In Out</string>
          <key>CFBundleName</key>
          <string>Auto Switch In Out</string>
          <key>CFBundleExecutable</key>
          <string>auto-switch-in-out-menubar</string>
          <key>CFBundleIdentifier</key>
          <string>com.auto-switch-in-out-menubar.app</string>
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
    assert_match(/Mach-O/, shell_output("file -b #{macos_dir}/auto-switch-in-out-menubar"))
    assert_match(/Mach-O/, shell_output("file -b #{macos_dir}/toast"))
    assert_predicate libexec/APP_BUNDLE_NAME/"Contents/Info.plist", :exist?
    system "/usr/bin/codesign", "--verify", libexec/APP_BUNDLE_NAME
  end
end
