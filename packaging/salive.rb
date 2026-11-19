# Template for the Homebrew tap (github.com/fcemtopall/homebrew-tap/Casks/salive.rb).
# The release workflow fills in VERSION and SHA256 and pushes it to the tap.
cask "salive" do
  version "__VERSION__"
  sha256 "__SHA256__"

  url "https://github.com/fcemtopall/sAlive/releases/download/v#{version}/sAlive-#{version}.zip"
  name "sAlive"
  desc "Keep the computer awake from Control Center, even with the lid closed"
  homepage "https://github.com/fcemtopall/sAlive"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :tahoe

  app "sAlive.app"
  binary "#{appdir}/sAlive.app/Contents/Helpers/salive"

  # Never leave the Mac unable to sleep after uninstalling.
  uninstall_preflight_steps do
    run "/usr/bin/pmset",
        args:         ["-a", "disablesleep", "0"],
        sudo:         true,
        must_succeed: false
  end

  uninstall launchctl: "io.github.fcemtopall.salive.helper",
            quit:      "io.github.fcemtopall.salive"

  zap trash: "/Library/Application Support/sAlive"

  caveats <<~EOS
    Open sAlive once and allow its helper in
      System Settings › General › Login Items & Extensions.
    Then add “Keep Awake” via Control Center › Edit Controls, or run `salive on`.
  EOS
end
