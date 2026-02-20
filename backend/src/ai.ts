export type ChatMessage = {
  role: string;
  content: string;
};

// This project runs on Bun; we keep types local to avoid requiring extra @types deps.
declare const process: { env: Record<string, string | undefined> };

export type GeneratedModule =
  | { type: "info"; content: { markdown: string } }
  | { type: "test"; content: { question: string; options: string[]; correctIndex: number } };

export type GeneratedCourse = {
  courseName: string;
  modules: GeneratedModule[];
};

function errJson(status: number, error: string): Response {
  return new Response(JSON.stringify({ error }), {
    status,
    headers: { "content-type": "application/json" }
  });
}

function asString(value: unknown): string | null {
  return typeof value === "string" ? value : null;
}

function clampInt(n: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, n | 0));
}

function stripCodeFences(text: string): string {
  const t = text.trim();
  if (!t.startsWith("```")) return t;
  // Handle ```json ... ``` and plain ``` ... ```
  const firstNewline = t.indexOf("\n");
  if (firstNewline === -1) return t;
  const withoutFirstFence = t.slice(firstNewline + 1);
  const lastFence = withoutFirstFence.lastIndexOf("```");
  return (lastFence === -1 ? withoutFirstFence : withoutFirstFence.slice(0, lastFence)).trim();
}

function extractLikelyJsonObject(text: string): string {
  const t = stripCodeFences(text);
  const start = t.indexOf("{");
  const end = t.lastIndexOf("}");
  if (start === -1 || end === -1 || end <= start) return t.trim();
  return t.slice(start, end + 1).trim();
}

function validateGeneratedCourse(value: unknown): GeneratedCourse {
  if (!value || typeof value !== "object") throw errJson(502, "ai_invalid_output");
  const obj = value as any;

  const courseName = asString(obj.courseName);
  if (!courseName) throw errJson(502, "ai_invalid_output");

  if (!Array.isArray(obj.modules)) throw errJson(502, "ai_invalid_output");

  const modules: GeneratedModule[] = [];
  for (const m of obj.modules) {
    if (!m || typeof m !== "object") throw errJson(502, "ai_invalid_output");
    const mm = m as any;
    const type = asString(mm.type);
    const content = mm.content;

    if (type === "info") {
      const markdown = asString(content?.markdown);
      if (!markdown) throw errJson(502, "ai_invalid_output");
      modules.push({ type: "info", content: { markdown } });
      continue;
    }

    if (type === "test") {
      const question = asString(content?.question);
      const options = Array.isArray(content?.options)
        ? content.options.filter((x: unknown) => typeof x === "string")
        : null;
      const correctIndexRaw = content?.correctIndex;
      const correctIndexNum = typeof correctIndexRaw === "number" ? correctIndexRaw : Number(correctIndexRaw);

      if (!question || !options || options.length < 2 || !Number.isFinite(correctIndexNum)) {
        throw errJson(502, "ai_invalid_output");
      }
      const correctIndex = clampInt(correctIndexNum, 0, options.length - 1);
      modules.push({ type: "test", content: { question, options, correctIndex } });
      continue;
    }

    throw errJson(502, "ai_invalid_output");
  }

  if (modules.length === 0) throw errJson(502, "ai_invalid_output");
  return { courseName, modules };
}

function sanitizeChatMessages(messages: ChatMessage[]): { role: "user" | "assistant"; content: string }[] {
  const out: { role: "user" | "assistant"; content: string }[] = [];
  for (const m of messages) {
    if (!m || typeof m !== "object") continue;
    const content = typeof (m as any).content === "string" ? (m as any).content.trim() : "";
    if (!content) continue;

    const roleRaw = typeof (m as any).role === "string" ? (m as any).role : "user";
    // Prevent user-supplied system prompts from overriding our constraints.
    const role: "user" | "assistant" = roleRaw === "assistant" ? "assistant" : "user";

    out.push({ role, content });
  }
  return out;
}

function systemPrompt(): string {
  return [
    "You are an AI that generates a short course from a chat conversation.",
    "",
    "Return ONLY a JSON object (no markdown, no code fences) with this exact schema:",
    "{",
    '  \"courseName\": string,',
    '  \"modules\": [',
    '    { \"type\": \"info\", \"content\": { \"markdown\": string } },',
    '    { \"type\": \"test\", \"content\": { \"question\": string, \"options\": string[], \"correctIndex\": number } }',
    "  ]",
    "}",
    "",
    "Rules:",
    "- modules must be an array of exactly 4 items.",
    "- Include exactly 2 info modules and 2 test modules.",
    "- Each test module must have exactly 4 options.",
    "- correctIndex must be an integer index into options (0..3).",
    "- The info markdown should be reasonably short and readable, with at least one heading.",
    "",
    "Do not include any other keys."
  ].join("\n");
}

export async function generateCourseFromChat(messages: ChatMessage[]): Promise<GeneratedCourse> {
  const apiKey = process.env.OPENROUTER_API_KEY;
  if (!apiKey) throw errJson(500, "missing_openrouter_api_key");

  const baseUrl = (process.env.OPENROUTER_BASE_URL ?? "https://openrouter.ai/api/v1").replace(/\/+$/, "");
  const model = process.env.OPENROUTER_MODEL ?? "arcee-ai/trinity-large-preview:free";
  const timeoutMsRaw = Number(process.env.OPENROUTER_TIMEOUT_MS ?? 20000);
  const timeoutMs = Number.isFinite(timeoutMsRaw) ? timeoutMsRaw : 20000;

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), Math.max(1, timeoutMs));
  try {
    const res = await fetch(`${baseUrl}/chat/completions`, {
      method: "POST",
      headers: {
        authorization: `Bearer ${apiKey}`,
        "content-type": "application/json"
      },
      body: JSON.stringify({
        model,
        temperature: 0.2,
        max_tokens: 1200,
        messages: [{ role: "system", content: systemPrompt() }, ...sanitizeChatMessages(messages)]
      }),
      signal: controller.signal
    });

    if (!res.ok) {
      throw errJson(502, "ai_unavailable");
    }

    const data = (await res.json()) as any;
    const content = asString(data?.choices?.[0]?.message?.content);
    if (!content) throw errJson(502, "ai_invalid_output");

    const jsonText = extractLikelyJsonObject(content);
    let parsed: unknown;
    try {
      parsed = JSON.parse(jsonText);
    } catch {
      throw errJson(502, "ai_invalid_output");
    }

    return validateGeneratedCourse(parsed);
  } catch (e) {
    if (e instanceof Response) throw e;
    // AbortError / network errors / unexpected runtime errors.
    throw errJson(502, "ai_unavailable");
  } finally {
    clearTimeout(timeout);
  }
}

