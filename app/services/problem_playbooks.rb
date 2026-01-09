# app/services/problem_playbooks.rb
# Lightweight intent detection + highly variable “Mom voice” troubleshooting playbooks.

class ProblemPlaybooks
  INTENTS = {
    wifi: [
      "wifi", "wi-fi", "internet", "no internet", "offline", "router", "modem",
      "connected no internet", "cant connect", "won't connect"
    ],
    password_reset: [
      "forgot password", "reset password", "password reset", "can't log in", "cant log in",
      "locked out", "account locked", "wrong password"
    ],
    email_hacked: [
      "hacked", "someone logged in", "unrecognized login", "suspicious sign-in",
      "email hacked", "my email was hacked", "someone changed my password"
    ],
    storage_full: [
      "storage full", "icloud full", "not enough storage", "low storage",
      "out of space", "space is full", "cannot download"
    ],
    printer: [
      "printer", "won't print", "wont print", "printing", "paper jam",
      "offline printer", "printer offline"
    ],
    device_slow: [
      "slow", "lag", "freezing", "frozen", "crashing", "keeps closing",
      "spinning", "stuck", "unresponsive"
    ],
    popup_scammy: [
      "pop up", "popup", "virus", "infected", "call this number", "security alert",
      "your computer is infected", "microsoft warning", "apple warning"
    ],
    subscription_charge: [
      "charged", "charge", "subscription", "bill", "refund", "invoice",
      "renewal", "trial", "cancel"
    ]
  }.freeze

  # ---------- Variation pools ----------
  OPENERS = [
    "Okay—this one’s common. We got it.",
    "Alright. I know this type of problem.",
    "Yep, seen it. Let’s fix it without making it worse.",
    "Cool. We can handle this—step by step.",
    "Okay—no panic. We’ll untangle it.",
    "Alright. I’m on your side. Let’s get you unstuck."
  ].freeze

  CURMUDGEON = [
    "We’re not doing guess-clicking.",
    "We’re doing clean steps, not chaos.",
    "No rushing. Rushing breaks stuff.",
    "We verify first, then we tap.",
    "If anything asks for codes or remote access, we stop.",
    "I’m friendly, but I don’t trust random prompts."
  ].freeze

  DEVICE_QUESTION = [
    "Quick: iPhone, Android, Windows, or Mac?",
    "What device are you on—phone or computer?",
    "What kind of phone/computer is it?",
    "Is this on your phone, laptop, or tablet?"
  ].freeze

  def self.detect_intent(normalized_text)
    t = normalized_text.to_s
    INTENTS.each do |intent, tokens|
      return intent if tokens.any? { |tok| t.include?(tok) }
    end
    nil
  end

  def self.response_for(intent:, user_id: nil, conversation_id: nil, raw_text: "")
    rng = seeded_rng(user_id: user_id, conversation_id: conversation_id, raw_text: raw_text)

    case intent
    when :wifi
      wifi_response(rng)
    when :password_reset
      password_reset_response(rng)
    when :email_hacked
      email_hacked_response(rng)
    when :storage_full
      storage_full_response(rng)
    when :printer
      printer_response(rng)
    when :device_slow
      slow_device_response(rng)
    when :popup_scammy
      popup_response(rng)
    when :subscription_charge
      subscription_response(rng)
    else
      nil
    end
  end

  # ---------- Playbooks ----------

  def self.wifi_response(rng)
    summary = [
      pick(rng, OPENERS),
      pick(rng, CURMUDGEON),
      "Let’s figure out if it’s your device, the Wi-Fi, or the internet itself.",
      pick(rng, DEVICE_QUESTION)
    ].join(" ")

    steps = shuffle_take(rng, [
      "Are other devices on the same Wi-Fi working (another phone/TV)?",
      "Look at the Wi-Fi icon—does it say connected but ‘No Internet’?",
      "Restart: unplug modem/router for 20 seconds, plug back in, wait 2–3 minutes.",
      "If you’re on a phone, toggle Airplane Mode on/off once.",
      "Forget the Wi-Fi network and re-join (only if you know the password).",
      "If you’re using a cable modem, check if the modem ‘Online’ light is solid."
    ], 4, 6)

    finish(rng, summary, steps, "v1_wifi_playbook")
  end

  def self.password_reset_response(rng)
    summary = [
      pick(rng, OPENERS),
      pick(rng, CURMUDGEON),
      "Password resets are where scams hide, so we do it clean.",
      "Which account is it—email, bank, Apple ID, Google, Facebook?"
    ].join(" ")

    steps = shuffle_take(rng, [
      "Tell me the *exact* app/site name you’re logging into.",
      "Did *you* request a reset, or did a message tell you to reset?",
      "Only reset from the official app or official website (typed manually). Don’t use random links.",
      "If you can’t log in: try ‘Forgot Password’ and check your email for the reset message.",
      "If it asks for a code, that code should come to *you* (text/email). Don’t share it with anyone.",
      "If you keep getting ‘wrong password’, confirm Caps Lock and try the last password you remember once—then stop."
    ], 4, 6)

    finish(rng, summary, steps, "v1_password_reset_playbook")
  end

  def self.email_hacked_response(rng)
    summary = [
      "Alright—if this is a real hack, we move fast and smart.",
      pick(rng, CURMUDGEON),
      "We lock it down first, then clean up.",
      "Which email is it (Gmail, Yahoo, Outlook, iCloud)?"
    ].join(" ")

    steps = shuffle_take(rng, [
      "Change the email password *from the official site/app*.",
      "Turn on 2-factor authentication (2FA) after you change the password.",
      "Check ‘Security’ / ‘Devices’ / ‘Recent activity’ and sign out of devices you don’t recognize.",
      "Check forwarding rules: hackers love auto-forwarding your emails.",
      "If recovery email/phone was changed, change it back right away.",
      "If your bank is tied to this email, watch for password reset emails and alerts."
    ], 4, 6)

    finish(rng, summary, steps, "v1_email_hacked_playbook", escalate: true, confidence: 0.93)
  end

  def self.storage_full_response(rng)
    summary = [
      pick(rng, OPENERS),
      "Storage full is annoying, but fixable.",
      pick(rng, CURMUDGEON),
      "Are you seeing ‘iCloud Storage Full’ or ‘Device Storage Full’?"
    ].join(" ")

    steps = shuffle_take(rng, [
      "Tell me the device type (iPhone/Android) and whether it’s iCloud/Google Photos.",
      "Delete large videos first (they’re usually the big culprit).",
      "Clear ‘Recently Deleted’ photos/videos (otherwise they still take space).",
      "Uninstall apps you don’t use (you can reinstall later).",
      "If it’s cloud storage: consider upgrading *or* turn off photo backup temporarily.",
      "Restart after cleanup—sometimes the storage number updates late."
    ], 4, 6)

    finish(rng, summary, steps, "v1_storage_playbook")
  end

  def self.printer_response(rng)
    summary = [
      pick(rng, OPENERS),
      "Printers are… spiritually difficult 😤",
      pick(rng, CURMUDGEON),
      "But we can usually fix it in a few checks."
    ].join(" ")

    steps = shuffle_take(rng, [
      "Is it printing from a phone or from a computer?",
      "Does the printer screen say ‘Offline’ or show an error?",
      "Power cycle printer: off 10 seconds, back on.",
      "If it’s Wi-Fi printer: confirm printer is on the same Wi-Fi network as the device.",
      "Check paper + ink/toner + any jam door open.",
      "If it’s a Windows computer: remove the printer and re-add it (last resort)."
    ], 4, 6)

    finish(rng, summary, steps, "v1_printer_playbook")
  end

  def self.slow_device_response(rng)
    summary = [
      pick(rng, OPENERS),
      pick(rng, CURMUDGEON),
      "Slow can be storage, too many apps, bad Wi-Fi, or an update stuck.",
      pick(rng, DEVICE_QUESTION)
    ].join(" ")

    steps = shuffle_take(rng, [
      "Restart the device once (simple, but it works).",
      "Close extra apps/tabs—especially browsers.",
      "Check storage: if it’s near full, performance drops.",
      "Check for system updates (but don’t install random ‘cleaner’ apps).",
      "If it only happens on one site/app, tell me which one.",
      "If it heats up a lot, let it cool down—heat makes everything slow."
    ], 4, 6)

    finish(rng, summary, steps, "v1_slow_device_playbook")
  end

  def self.popup_response(rng)
    summary = [
      "Stop—don’t click anything on that pop-up yet.",
      pick(rng, CURMUDGEON),
      "If it says ‘call now’ or ‘infected’, that’s usually scammy.",
      "Tell me the exact words and whether there’s a phone number on screen."
    ].join(" ")

    steps = shuffle_take(rng, [
      "Do NOT call any number on the pop-up.",
      "Close the browser tab/app. If it won’t close, force quit the browser.",
      "If on Windows: open Task Manager and end the browser task.",
      "After closing: reopen browser and clear recent browsing data for the last hour/day.",
      "If it keeps coming back, tell me what browser (Chrome/Safari/Edge) and we’ll remove extensions.",
      "If you installed anything because of it, tell me what it was."
    ], 4, 6)

    finish(rng, summary, steps, "v1_popup_playbook", escalate: true, confidence: 0.94)
  end

  def self.subscription_response(rng)
    summary = [
      pick(rng, OPENERS),
      pick(rng, CURMUDGEON),
      "Charges/subscriptions can be legit OR a trap—so we verify.",
      "Is this Apple, Google, Amazon, bank statement, or an email invoice?"
    ].join(" ")

    steps = shuffle_take(rng, [
      "Tell me where you saw the charge (bank app, email, text, inside an app).",
      "If it’s email: don’t click links—open your bank/app store directly.",
      "Check subscriptions in Apple ID / Google Play (official settings).",
      "If you don’t recognize it: mark it, don’t pay via links, and contact the bank/app store from official numbers.",
      "If it’s a trial renewal: cancel in subscriptions and ask for refund through official support.",
      "If it’s ‘refund department’ calling you—assume scam until proven otherwise."
    ], 4, 6)

    finish(rng, summary, steps, "v1_subscription_playbook", escalate: true, confidence: 0.90)
  end

  # ---------- helpers ----------
  def self.finish(rng, summary, steps, prompt_version, escalate: false, confidence: 0.88)
    # tiny “alive” variation: optional tag line
    if rng.rand < 0.18
      summary = "#{summary} (We’ll do it clean.)"
    end

    {
      risk_level: escalate ? "high" : "medium",
      summary: summary,
      steps: steps,
      escalate_suggested: escalate,
      confidence: confidence,
      model: "stub",
      prompt_version: prompt_version
    }
  end

  def self.shuffle_take(rng, arr, min_n, max_n)
    n = min_n + rng.rand((max_n - min_n) + 1)
    arr.shuffle(random: rng).take(n) + extra_line(rng)
  end

  def self.extra_line(rng)
    return [] unless rng.rand < 0.35
    [
      pick(rng, [
        "If you can, paste the exact wording. Exact words matter.",
        "If you’re not sure, describe it like you’re describing a photo to me.",
        "Tell me what the buttons say—those words are clues.",
        "One thing at a time. You’re doing fine."
      ])
    ]
  end

  def self.seeded_rng(user_id:, conversation_id:, raw_text:)
    base = [
      Time.now.to_i,
      (user_id || 0),
      (conversation_id || 0),
      raw_text.to_s.bytes.sum,
      rand(1_000_000)
    ].join(":")

    seed = base.bytes.reduce(0) { |acc, b| (acc * 131 + b) & 0x7fffffff }
    Random.new(seed)
  end

  def self.pick(rng, arr)
    arr[rng.rand(arr.length)]
  end
end