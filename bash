// api/generate.js
export default async function handler(req, res) {
  try {
    if (req.method !== "POST") {
      return res.status(405).json({ error: "Use POST" });
    }
    const { subject } = await readJson(req);
    if (!subject || typeof subject !== "string") {
      return res.status(400).json({ error: "Provide 'subject' (string)" });
    }

    const system = `
You are a Christian prayer companion that builds a compact JSON "prayer journey"
for ANY subject the user enters. Follow this exact schema and keep outputs concise:

{
  "subject": "string",
  "scriptures": [
    { "ref": "Book Chapter:Verses", "text": "string", "translation": "KJV|WEB" }
  ],
  "meditation_imagery": "string",
  "symbolism": {
    "colors": ["string"],
    "numbers": ["string"],
    "symbols": ["string"]
  },
  "written_prayers": ["string"],
  "saints": [
    { "name": "string", "why_relevant": "string", "feast_day": "MM-DD" }
  ],
  "extras": {
    "hymns_or_music": ["string"],
    "breath_prayer": "string",
    "lectio_divina_steps": ["Read", "Meditate", "Pray", "Contemplate"],
    "artwork_suggestion": "string",
    "reflection_timer_minutes": 5,
    "journal_prompt": "string"
  }
}

Rules:
- Return ONLY valid JSON (no commentary).
- Prefer public‑domain Bible translations: KJV or WEB.
- 2–4 scriptures total. Quote accurately and keep verses short.
- 1 meditation image idea.
- 2–3 colors, 1–2 numbers, 1–3 symbols.
- 1 short written prayer (4–6 sentences).
- 1 breath prayer (<=12 words).
- 2–3 saints (or notable Christian figures) and why they relate.
- Pastoral, ecumenical tone. If subject is sensitive/crisis, add
  extras.journal_prompt that encourages seeking help and prayer; do NOT give clinical advice.
`;

    const user = `Subject: ${subject}`;

    const resp = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${process.env.OPENAI_API_KEY}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        model: "gpt-4o-mini", // any current, cost-effective model works
        temperature: 0.7,
        messages: [
          { role: "system", content: system },
          { role: "user", content: user }
        ],
        response_format: { type: "json_object" } // forces valid JSON
      })
    });

    if (!resp.ok) {
      const err = await resp.text();
      return res.status(500).json({ error: "LLM error", details: err });
    }

    const data = await resp.json();
    const content = data.choices?.[0]?.message?.content;
    // content is a JSON string per response_format
    let payload;
    try { payload = JSON.parse(content); }
    catch (e) { return res.status(500).json({ error: "Invalid JSON from model" }); }

    // Attach a tiny “safety note” for crisis topics (non-clinical)
    if (/(suicide|self-harm|abuse|assault|kill myself|harm myself)/i.test(subject)) {
      payload.safety = "If you or someone is in immediate danger, contact local emergency services or a trusted hotline in your country.";
    }

    res.setHeader("Content-Type", "application/json");
    return res.status(200).send(JSON.stringify(payload));
  } catch (e) {
    return res.status(500).json({ error: "Server error", details: e?.message });
  }
}

function readJson(req) {
  return new Promise((resolve, reject) => {
    let body = "";
    req.on("data", chunk => body += chunk);
    req.on("end", () => {
      try { resolve(JSON.parse(body || "{}")); }
      catch (e) { reject(e); }
    });
  });
}
