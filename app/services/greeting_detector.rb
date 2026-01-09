# app/services/greeting_detector.rb
# Robust "no missed greeting" + highly variable responses (cheap AI feel, no LLM)

class GreetingDetector
  GREETING_TOKENS = %w[
    hi hello hey heyy heyyy hii hiii yo sup wassup wazzup howdy
    hola buenas buenass buen dia buenos dias buenas tardes buenas noches
    que onda qonda q onda queonda
    oi ayy ey eyy
    saludos
  ].freeze

  OPENER_PHRASES = [
    /\Acan you help( me)?\??\z/i,
    /\Ahelp( me)?\??\z/i,
    /\Aare you there\??\z/i,
    /\Ayou there\??\z/i,
    /\Ahi+\b/i,
    /\Ahey+\b/i,
    /\Ahello+\b/i,
    /\Ahola+\b/i,
    /\Ayo+\b/i,
    /\Asup\b/i,
    /\Awass?up\b/i,
    /\Awhat'?s up\b/i,
    /\Agood (morning|afternoon|evening)\b/i
  ].freeze

  HIGH_RISK_HINTS = [
    "gift card", "itunes", "google play", "steam card",
    "wire transfer", "western union", "moneygram",
    "crypto", "bitcoin", "ethereum",
    "remote access", "anydesk", "teamviewer", "logmein",
    "bank login", "routing number", "account number",
    "verification code", "2fa code", "one-time code", "otp",
    "refund", "chargeback", "invoice", "past due",
    "microsoft support", "apple support", "security alert",
    "your computer is infected", "virus", "trojan"
  ].freeze

  # ---------------------------
  # Variation pools (WAY bigger)
  # ---------------------------

  OPENERS = [
    "Hey—Mom’s Computer here.",
    "Hi. Mom’s Computer checking in.",
    "Alright, I’m here. Mom’s Computer.",
    "Yo—Mom’s Computer on deck.",
    "Hola 🙂 Mom’s Computer aquí.",
    "Okay. Talk to me—Mom’s Computer.",
    "Alright—what’s the situation?",
    "Hey there—what happened?",
    "Hi hi. What are we dealing with?",
    "Alright, I’ve got you.",
    "Yo. You’re safe with me—what’s up?",
    "Hey. Let’s handle this together.",
    "Okay—deep breath. What’s going on?",
    "Mom’s Computer. I’m listening.",
    "Alright—start from the top for me.",
    "Hey—tell me what you’re seeing.",
    "Hi. What’s acting up today?",
    "Okay—what’s the screen yelling at you?",
    "Hey—what were you trying to do?",
    "Alright, we can fix this."
  ].freeze

  CURMUDGEON_BITS = [
    "We’re gonna do this the safe way.",
    "We’re not clicking random buttons today.",
    "Nobody’s taking your money on my watch.",
    "We keep it simple, calm, and safe.",
    "I’ve seen this movie before. We’re not falling for it.",
    "If it smells weird, we pause. Period.",
    "No rushing. Rushing is how people get scammed.",
    "We’re not ‘confirming’ anything until we know what it is.",
    "We don’t trust pop-ups that shout.",
    "If something is urgent, it’ll still be urgent in 30 seconds.",
    "We’re gonna verify first, then move.",
    "I’m friendly, but I’m not gullible. Neither are you.",
    "We’re gonna fix the problem *and* keep you safe.",
    "We don’t do panic-clicking in this house.",
    "We go slow so you don’t pay twice—money or stress.",
    "We’re not handing strangers the keys to your phone.",
    "If it’s legit, it can wait for one good question.",
    "We don’t install anything until we know what it is.",
    "You’re not bothering me—this is what I’m for.",
    "Let’s get you unstuck without any nonsense."
  ].freeze

  SAFETY_REMINDERS = [
    "Quick rule: no passwords, no login codes, no gift cards.",
    "Rule #1: don’t share codes or passwords. Ever.",
    "If anyone asks for money, codes, or remote access—stop and tell me.",
    "If a pop-up is yelling at you, we slow down and verify.",
    "Never read a 6-digit code out loud to anyone. That code is for *you*.",
    "No bank info. No SSN. No “verify your identity” surprises.",
    "If someone pressures you, that’s a red flag. Period.",
    "If they say ‘don’t hang up’—hang up.",
    "If they want you to install an app to ‘fix it’—pause and tell me.",
    "We don’t send money to ‘unlock’ devices. That’s not a thing.",
    "If it’s a ‘refund’ situation, it’s often a scam. We check first.",
    "If the message creates panic, we treat it as suspicious until proven otherwise."
  ].freeze

  FIRST_QUESTIONS = [
    "What are you looking at right now on the screen?",
    "Tell me what you see—exact words if you can.",
    "What did you click right before it got weird?",
    "What are you trying to do—pay a bill, reset a password, log in?",
    "What device is it—iPhone, Android, Windows, or Mac?",
    "Is this happening in an app, a website, email, or a pop-up?",
    "Did this start after you opened a link or attachment?",
    "Are you at home on Wi-Fi or using cellular data?",
    "Is it asking you to ‘Allow’, ‘Install’, ‘Verify’, or ‘Call a number’?",
    "Did someone contact you first, or did this appear by itself?",
    "What’s the one thing you want to accomplish right now?",
    "Are you locked out, or is it just acting slow/weird?",
    "Is it one device or multiple devices having the issue?",
    "Are you seeing an error code or just a message?",
    "Does it look like a warning from Apple/Google/Microsoft—or just a random page?",
    "Are there any buttons? Tell me the button words."
  ].freeze

  STEP_POOL = [
    "What device is it (iPhone/Android/Mac/Windows)?",
    "What app or website are you in?",
    "What were you trying to do right before this happened?",
    "Copy/paste the message you see (or describe it).",
    "Is anyone asking for money, gift cards, codes, passwords, or remote access?",
    "Did this come from an email, a text, a phone call, or a pop-up?",
    "If a button says “Allow” / “Install” / “Download”, don’t tap yet—tell me what it says.",
    "If it’s a password reset, tell me *where* the reset request came from.",
    "If you can, take a screenshot (don’t include passwords) and describe what’s highlighted.",
    "Tell me if it says ‘urgent’, ‘security’, ‘locked’, or ‘infected’. Exact words matter.",
    "What time did it start and has it happened before?",
    "Did you recently install anything new?",
    "Are you on Wi-Fi right now? If yes, which network name?",
    "Are there any phone numbers on the screen? Tell me the numbers (don’t call them yet).",
    "If you see a browser tab name, tell me that too.",
    "Tell me what the top of the screen says (app name / website)."
  ].freeze

  SOCAL_FLAVOR = [
    "Alright—SoCal rules: verify first, then move.",
    "We’re keeping it calm—like a Sunday in Bellflower.",
    "No stress. We’ll handle it—LA style: patient, sharp, and safe.",
    "We’re not letting some random pop-up run the neighborhood.",
    "Okay—slow is smooth, smooth is fast. That’s the LA way.",
    "We got you. Community care energy.",
    "We protect our elders out here. That includes you."
  ].freeze

  SUMMARY_TEMPLATES = [
    "%{opener} %{curmudgeon} %{safety} %{question}",
    "%{opener} %{question} %{curmudgeon} %{safety}",
    "%{opener} %{curmudgeon} %{question}",
    "%{opener} %{safety} %{question}",
    "%{opener} %{curmudgeon} %{question} %{safety}",
    "%{opener} %{question} %{safety}",
    "%{opener} %{question} %{curmudgeon}"
  ].freeze

  EMOJI = ["🙂", "👍", "🧠", "🛡️", "😤", "✅", "🫡", "💬", "🔒", "🧯"].freeze

  def self.normalize(raw)
    raw.to_s
       .downcase
       .gsub(/[“”]/, '"')
       .gsub(/[‘’]/, "'")
       .gsub(/[^a-z0-9\s\?\!\.\,\-]/, " ")
       .gsub(/\s+/, " ")
       .strip
  end

  def self.greeting?(raw_text)
    raw = raw_text.to_s
    t = normalize(raw)

    return true if t.empty?
    return false if includes_any?(t, HIGH_RISK_HINTS)

    return true if token_greeting?(t)
    return true if opener_phrase?(t)
    return true if low_signal?(raw, t)

    false
  end

  def self.response(user_id: nil, conversation_id: nil, raw_text: "")
    rng = seeded_rng(user_id: user_id, conversation_id: conversation_id, raw_text: raw_text)

    opener = pick(rng, OPENERS)
    curm = pick(rng, CURMUDGEON_BITS)
    safety = pick(rng, SAFETY_REMINDERS)
    question = pick(rng, FIRST_QUESTIONS)

    curm = "#{curm} #{pick(rng, SOCAL_FLAVOR)}" if rng.rand < 0.22

    summary = format_summary(rng, opener: opener, curmudgeon: curm, safety: safety, question: question)

    steps = build_steps(rng)

    # Small extra “alive” touch
    if rng.rand < 0.18
      summary = "#{summary} #{pick(rng, EMOJI)}"
    end

    {
      risk_level: "low",
      summary: summary,
      steps: steps,
      escalate_suggested: false,
      confidence: 0.92,
      model: "stub",
      prompt_version: "v4_greeting_massive_variants"
    }
  end

  # ---------------------------
  # Internals
  # ---------------------------

  def self.format_summary(rng, opener:, curmudgeon:, safety:, question:)
    template = pick(rng, SUMMARY_TEMPLATES)
    s = template % { opener: opener, curmudgeon: curmudgeon, safety: safety, question: question }

    # punctuation micro-variation
    s = s.gsub("—", "-") if rng.rand < 0.12
    s = s.gsub("...", ".") if rng.rand < 0.55
    s = s + "?" if (!s.end_with?("?") && rng.rand < 0.10)

    s
  end

  def self.build_steps(rng)
    n = 3 + rng.rand(4) # 3..6
    steps = STEP_POOL.shuffle(random: rng).take(n)

    if rng.rand < 0.40
      steps = steps.map do |x|
        x.sub(/\AWhat /, "Real quick—what ")
         .sub(/\ATell me /, "Real quick—tell me ")
      end
    end

    steps << "If you can, type the *exact* words you see. One line at a time is fine." if rng.rand < 0.55
    steps << "And don’t worry—this stuff is confusing on purpose sometimes. We’ll sort it out." if rng.rand < 0.25

    steps
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

  def self.token_greeting?(t)
    first = t.split(" ").first.to_s
    return true if GREETING_TOKENS.include?(first)
    return true if GREETING_TOKENS.any? { |g| t.start_with?(g + " ") || t == g }
    false
  end

  def self.opener_phrase?(t)
    OPENER_PHRASES.any? { |rx| t.match?(rx) }
  end

  def self.low_signal?(raw, normalized)
    return true if normalized.length <= 4
    return true if normalized.length <= 16 && normalized.split.size <= 2
    return true if mostly_non_alnum?(raw)

    if normalized.length <= 44
      words = normalized.split
      return true if words.size <= 6 && looks_like_keyboard_mash?(normalized)
      return true if words.size <= 3
    end

    false
  end

  def self.mostly_non_alnum?(raw)
    s = raw.to_s
    return true if s.strip.empty?
    total = s.length.to_f
    alnum = s.count("A-Za-z0-9").to_f
    (alnum / total) < 0.20
  end

  def self.looks_like_keyboard_mash?(t)
    letters = t.gsub(/[^a-z]/, "")
    return false if letters.length < 4
    vowels = letters.count("aeiou").to_f
    ratio = vowels / letters.length.to_f
    ratio < 0.20
  end

  def self.includes_any?(t, arr)
    arr.any? { |x| t.include?(x) }
  end
end