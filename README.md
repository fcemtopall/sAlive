# sAlive ☕️

**Keep your Mac awake from Control Center – even with the lid closed.**
One tap instead of `sudo pmset -a disablesleep 1`.

[Türkçe](#türkçe) · [English](#english)

---

## English

macOS puts your Mac to sleep after a while once the display turns off or the lid closes – even with "prevent sleep" style settings. The only reliable fix is `sudo pmset -a disablesleep 1`, which means opening Terminal and typing your password every time.

sAlive turns that into a button:

- **Control Center toggle** – add “Keep Awake” via *Control Center › Edit Controls*
- **Menu bar icon** – on/off, timers (30 min · 1 h · 3 h · 8 h · ∞), status
- **Auto-off timer** – survives app quit and reboot
- **Low-battery cutoff** – turns itself off at 10 / 20 / 30 / 50 % on battery
- **You choose where it lives** – menu bar & Control Center, Control Center only (no menu bar icon; the toggle works even when the app isn't running), or menu bar only
- **CLI** – `salive on 2h`, `salive off`, `salive status`
- **English & Turkish** – follows your system language (override per app in *System Settings › General › Language & Region*)
- **No password prompts, no sudoers hacks** – a small signed helper registered with Apple's `SMAppService`, which you approve once in System Settings

### Install

```sh
brew install --cask fcemtopall/tap/salive
```

Or download the notarized `sAlive-x.y.z.zip` from [Releases](https://github.com/fcemtopall/sAlive/releases) and drag `sAlive.app` to `/Applications`.

Then:

1. Open **sAlive** and click **Install Helper**.
2. macOS opens *System Settings › General › Login Items & Extensions* – enable **sAlive**.
3. Choose where sAlive appears. For Control Center: *Control Center › Edit Controls* → search “sAlive” → add **Keep Awake** (shown as **Uyanık Tut** in Turkish).
   With the menu bar icon hidden, open sAlive again from Applications to reach its settings.

Requires macOS 26 (Tahoe) or later.

### CLI

```
salive on [DURATION]      # e.g. salive on, salive on 90m, salive on 1h30m
salive off
salive toggle
salive status
salive battery 20         # auto-off at 20 % battery (salive battery off to disable)
```

### ⚠️ Heads-up

With sleep disabled your Mac stays fully on with the lid closed. Don't leave it running in a bag – use a timer or the battery cutoff.

### Uninstall

```sh
brew uninstall --cask salive        # add --zap to remove saved settings
```

(Uninstalling turns keep-awake off first.) Manual install: open sAlive › Setup… › Uninstall Helper, then delete the app.

### How it works

```
Control Center toggle ─┐
Menu bar app ──────────┼── XPC (code-signature checked) ──► sAliveHelper (root, launchd)
salive CLI ────────────┘                                     └─ /usr/bin/pmset -a disablesleep 0|1
```

The helper only accepts connections from binaries signed by the same Apple Developer team, runs `pmset` with fixed arguments, and stores the timer / battery cutoff in `/Library/Application Support/sAlive/state.json`. Current state is always read from `pmset -g`, so changes made in Terminal show up too.

### Building

```sh
brew install xcodegen
xcodegen generate
open sAlive.xcodeproj
# or: scripts/dev-install.sh   (build Debug + install to /Applications)
```

Forks: set your own Team ID in `project.yml` (`DEVELOPMENT_TEAM`) **and** `Shared/Constants.swift` (`SAlive.teamID`), and change the `io.github.fcemtopall` bundle IDs.

> If your checkout lives in an iCloud-synced folder (Desktop/Documents), keep DerivedData outside it – iCloud's extended attributes break code signing.

Translations live in `App/Localizable.xcstrings` and `ControlExtension/Localizable.xcstrings` (edit in Xcode; new languages welcome).

Releasing: bump `MARKETING_VERSION` in `project.yml`, push a `vX.Y.Z` tag. The workflow signs, notarizes, publishes the release and updates the Homebrew tap. Required secrets: `DEVELOPER_ID_P12_BASE64`, `DEVELOPER_ID_P12_PASSWORD`, `ASC_KEY_P8_BASE64`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `HOMEBREW_TAP_TOKEN`.

---

## Türkçe

Mac'inizde ekran kapandığında ya da kapağı kapattığınızda, uyanık tutma ayarları açık olsa bile bir süre sonra bilgisayar uykuya geçer. Güvenilir tek çözüm `sudo pmset -a disablesleep 1` – yani her seferinde Terminal ve şifre.

sAlive bunu tek bir düğmeye çevirir:

- **Denetim Merkezi düğmesi** – *Denetim Merkezi › Denetimleri Düzenle* üzerinden “Uyanık Tut”u ekleyin
- **Menü çubuğu ikonu** – aç/kapat, süreli açma (30 dk · 1 sa · 3 sa · 8 sa · ∞)
- **Otomatik kapanma** – uygulama kapansa da, bilgisayar yeniden başlasa da çalışır
- **Düşük pil koruması** – pilde %10 / 20 / 30 / 50'ye inince kendini kapatır
- **Nerede görüneceğini sen seçersin** – menü çubuğu ve Denetim Merkezi, sadece Denetim Merkezi (menü ikonu gizli, uygulama çalışmasa da düğme çalışır) ya da sadece menü çubuğu
- **Terminal komutu** – `salive on 2h`, `salive off`, `salive status`
- **Türkçe ve İngilizce** – sistem dilini izler (uygulama bazında *Sistem Ayarları › Genel › Dil ve Bölge*'den değiştirilebilir)
- **Şifre yok, sudoers ayarı yok** – Apple'ın `SMAppService` altyapısıyla kayıtlı, imzalı küçük bir yardımcı servis; Ayarlar'dan bir kez onaylarsınız

### Kurulum

```sh
brew install --cask fcemtopall/tap/salive
```

Ya da [Releases](https://github.com/fcemtopall/sAlive/releases) sayfasından notarize edilmiş zip'i indirip `sAlive.app`'i `/Applications`'a sürükleyin.

1. **sAlive**'ı açın, **Install Helper**'a tıklayın.
2. Açılan *Sistem Ayarları › Genel › Giriş Öğeleri ve Uzantılar* ekranında **sAlive**'ı etkinleştirin.
3. sAlive'ın nerede görüneceğini seçin. Denetim Merkezi için: *Denetim Merkezi › Denetimleri Düzenle* → “sAlive” arayın → **Uyanık Tut**'u ekleyin.
   Menü ikonu gizliyse ayarlara ulaşmak için sAlive'ı Uygulamalar'dan tekrar açın.

macOS 26 (Tahoe) veya üstü gerekir.

### ⚠️ Uyarı

Uyku kapalıyken kapak kapalı olsa da Mac tamamen açık kalır. Çantada çalışır halde bırakmayın – süreli açmayı veya pil korumasını kullanın.

### Kaldırma

```sh
brew uninstall --cask salive        # ayarları da silmek için --zap
```

## License

MIT – see [LICENSE](LICENSE).
