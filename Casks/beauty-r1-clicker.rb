# typed: false
# frozen_string_literal: true

# Homebrew Cask for Beauty-R1 Clicker.
#
# This cask downloads a prebuilt, ad-hoc-signed BeautyR1Clicker.app from this
# repository's GitHub Releases and installs it into /Applications.
#
# Tap and install:
#
#   brew tap tnayuki/beauty-r1-clicker https://github.com/tnayuki/beauty-r1-clicker
#   brew install --cask beauty-r1-clicker
cask "beauty-r1-clicker" do
  version "1.1.1"
  sha256 "9fe6525b664d9d97528e423170fdb32bac4ca7682d58c32ea7f9b139075a47df"

  url "https://github.com/tnayuki/beauty-r1-clicker/releases/download/v#{version}/BeautyR1Clicker-#{version}.zip"
  name "Beauty-R1 Clicker"
  desc "Menu-bar app that turns the Beauty-R1 BLE clicker into arrow keys"
  homepage "https://github.com/tnayuki/beauty-r1-clicker"

  depends_on macos: ">= :monterey"

  app "Beauty-R1 Clicker.app"

  # The bundle is ad-hoc signed (no Developer ID); strip the quarantine xattr so
  # Gatekeeper doesn't block first launch.
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-d", "-r", "com.apple.quarantine", "#{appdir}/Beauty-R1 Clicker.app"],
                   sudo: false
  end

  zap trash: "~/Library/Preferences/dev.tnayuki.BeautyR1Clicker.plist"
end
