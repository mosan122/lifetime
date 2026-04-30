import { serve } from "https://deno.land/std@0.208.0/http/server.ts";

// ── Constants ─────────────────────────────────────────────────────────────────

const GEMINI_URL =
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const JSON_HEADERS = { ...CORS_HEADERS, "Content-Type": "application/json" };

// ── Types ─────────────────────────────────────────────────────────────────────

interface RequestBody {
  userNote: string;
  metadata?: { date?: string; location?: string };
  /** JPEG bytes compressed to ≤1024px by the client, Base64-encoded. */
  imageBase64?: string;
}

interface BiographerResult {
  title: string;
  narrative: string;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: JSON_HEADERS });
}

function formatDate(isoString?: string): string {
  const d = isoString ? new Date(isoString) : new Date();
  return d.toLocaleDateString("es-ES", {
    day: "numeric",
    month: "long",
    year: "numeric",
  });
}

/**
 * Extracts the JSON object the biographer model returned.
 * Uses `responseMimeType: "application/json"` so the model should already
 * return raw JSON, but we also handle the markdown-fenced fallback.
 */
function extractJson(text: string): BiographerResult {
  // Happy path: pure JSON
  try {
    return JSON.parse(text) as BiographerResult;
  } catch {
    // Fallback: extract first {...} block (markdown code fence, etc.)
    const match = text.match(/\{[\s\S]*\}/);
    if (match) return JSON.parse(match[0]) as BiographerResult;
    throw new Error(`Cannot extract JSON from model response: ${text}`);
  }
}

// ── Edge Function ─────────────────────────────────────────────────────────────

serve(async (req: Request): Promise<Response> => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    const apiKey = Deno.env.get("GEMINI_API_KEY");
    if (!apiKey) {
      return jsonResponse({ error: "GEMINI_API_KEY not configured" }, 500);
    }

    const { userNote, metadata, imageBase64 } =
      (await req.json()) as RequestBody;

    if (!userNote?.trim()) {
      return jsonResponse({ error: "userNote is required" }, 400);
    }

    // ── Build prompt ──────────────────────────────────────────────────────────

    const date = formatDate(metadata?.date);
    const locationLine = metadata?.location
      ? `\nLugar: ${metadata.location}`
      : "";

    const hasImage = !!imageBase64;

    const userText = hasImage
      ? `Escribe una narrativa biográfica para este recuerdo. Analiza la imagen adjunta y usa sus detalles visuales (objetos, personas, ambiente, luz, colores) para enriquecer y fundamentar la narrativa.\n\nFecha: ${date}${locationLine}\nNota del usuario: ${userNote}`
      : `Escribe una narrativa biográfica para este recuerdo.\n\nFecha: ${date}${locationLine}\nNota del usuario: ${userNote}`;

    // ── Build Gemini request parts ────────────────────────────────────────────
    // Image part must come before the text part (Gemini convention for vision).

    type Part =
      | { text: string }
      | { inlineData: { mimeType: string; data: string } };

    const parts: Part[] = [];
    if (hasImage) {
      parts.push({
        inlineData: {
          mimeType: "image/jpeg", // client always encodes as JPEG after resize
          data: imageBase64!,
        },
      });
    }
    parts.push({ text: userText });

    // ── Call Gemini ───────────────────────────────────────────────────────────

    const geminiBody = {
      systemInstruction: {
        parts: [
          {
            text: [
              "Eres un biógrafo personal y escritor literario.",
              "Tu misión es transformar los recuerdos espontáneos de las personas en narrativas reflexivas y emotivas que capturen la esencia de un momento vivido.",
              hasImage
                ? "Cuando el usuario comparte una foto, la analizas en detalle: objetos presentes, ambiente, personas, colores, luz y composición. Usas esos detalles visuales para confirmar y enriquecer la narrativa."
                : "",
              "",
              'Responde ÚNICAMENTE con un objeto JSON válido que contenga exactamente dos campos: "title" (máximo 60 caracteres, evocador y concreto) y "narrative" (3-5 frases en primera persona, estilo diario íntimo, reflexivo y emotivo).',
              "Nunca incluyas markdown, bloques de código ni texto adicional fuera del JSON.",
            ]
              .filter(Boolean)
              .join("\n"),
          },
        ],
      },
      contents: [{ role: "user", parts }],
      generationConfig: {
        temperature: 0.8,
        maxOutputTokens: 512,
        // Instructs the model to return raw JSON without markdown wrapping.
        responseMimeType: "application/json",
      },
    };

    const geminiRes = await fetch(`${GEMINI_URL}?key=${apiKey}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(geminiBody),
    });

    if (!geminiRes.ok) {
      const details = await geminiRes.text();
      console.error("Gemini API error:", details);
      return jsonResponse(
        { error: "Gemini API error", details },
        geminiRes.status
      );
    }

    // ── Parse response ────────────────────────────────────────────────────────

    const geminiData = await geminiRes.json();
    const rawText: string =
      geminiData?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";

    const { title, narrative } = extractJson(rawText);

    if (!title || !narrative) {
      throw new Error("Missing title or narrative in model response");
    }

    return jsonResponse({ title, narrative });
  } catch (err) {
    console.error("biographer-narrative error:", err);
    return jsonResponse({ error: String(err) }, 500);
  }
});
