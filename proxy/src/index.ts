// Photo -> meal proxy for the Calorie app.
//
// The app POSTs a food photo here; this Worker holds the Anthropic API key,
// asks Claude to identify the meal, and returns structured nutrition JSON.
// The key never ships inside the APK.
//
// POST /analyze
//   headers: Authorization: Bearer <APP_TOKEN>, X-Install-Id: <random id per install>
//   body:    { "image": "<base64 JPEG>", "localTime": "13:05", "note"?: "extra context" }
//   200:     Meal (see MEAL_SCHEMA)
//   4xx/5xx: { "error": "<code>", "message": "<readable>" }

import Anthropic from "@anthropic-ai/sdk";

export interface Env {
  ANTHROPIC_API_KEY: string;
  /** Shared secret the app sends. Not a strong secret (it lives in the APK), but it keeps casual traffic out and can be rotated. */
  APP_TOKEN: string;
  LIMITER: RateLimit;
}

const MODEL = "claude-opus-5-5";

/** Largest accepted photo, as base64 characters (~6 MB of JPEG). */
const MAX_IMAGE_CHARS = 8_000_000;

const MEAL_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["is_food", "dish", "emoji", "meal_type", "health_score", "items"],
  properties: {
    is_food: { type: "boolean", description: "False when the photo shows no food or drink." },
    dish: { type: "string", description: "Short name for the whole plate, e.g. \"Rajma chawal\"." },
    emoji: { type: "string", description: "One food emoji that fits the dish." },
    meal_type: { type: "string", enum: ["breakfast", "lunch", "dinner", "snack"] },
    health_score: { type: "integer", description: "1 (very unhealthy) to 10 (very healthy)." },
    items: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["name", "grams", "kcal", "protein", "carbs", "fat"],
        properties: {
          name: { type: "string" },
          grams: { type: "number", description: "Estimated edible weight in grams." },
          kcal: { type: "number" },
          protein: { type: "number", description: "grams" },
          carbs: { type: "number", description: "grams" },
          fat: { type: "number", description: "grams" },
        },
      },
    },
  },
} as const;

const SYSTEM = `You estimate the nutrition of meals from photos for a calorie-tracking app used mostly in India.

Identify each distinct food or drink on the plate as its own item (e.g. rice, dal, roti, sabzi, raita). Estimate the edible weight in grams from visual cues (plate and bowl size, utensils, hands, packaging) and give calories and macros for that weight, using typical home-style preparation, including cooking oil and ghee you can reasonably infer. Calories should be consistent with the macros (about 4 kcal per gram of protein and carbs, 9 per gram of fat). Prefer common everyday names a user would recognise, including Indian names where they fit.

Pick meal_type from what the food is and the user's local time. If the photo shows no food or drink, set is_food to false and return an empty items list.`;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

function fail(status: number, error: string, message: string): Response {
  return json({ error, message }, status);
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    if (request.method !== "POST" || url.pathname !== "/analyze") {
      return fail(404, "not_found", "Use POST /analyze.");
    }
    if (request.headers.get("authorization") !== `Bearer ${env.APP_TOKEN}`) {
      return fail(401, "unauthorized", "Missing or wrong app token.");
    }

    const installId = request.headers.get("x-install-id") ?? "anonymous";
    const { success } = await env.LIMITER.limit({ key: installId });
    if (!success) return fail(429, "rate_limited", "Too many photos at once. Try again in a minute.");

    let body: { image?: unknown; localTime?: unknown; note?: unknown };
    try {
      body = await request.json();
    } catch {
      return fail(400, "bad_request", "Body must be JSON.");
    }
    const image = typeof body.image === "string" ? body.image : "";
    if (!image || image.length > MAX_IMAGE_CHARS) {
      return fail(400, "bad_image", "Send one JPEG photo, base64-encoded, under about 6 MB.");
    }
    const localTime = typeof body.localTime === "string" ? body.localTime.slice(0, 5) : "unknown";
    const note = typeof body.note === "string" ? body.note.slice(0, 300) : "";

    const client = new Anthropic({ apiKey: env.ANTHROPIC_API_KEY });
    try {
      const response = await client.beta.messages.create({
        model: MODEL,
        max_tokens: 16000,
        // Re-runs a request the safety classifiers decline on Anthropic's recommended fallback model.
        betas: ["server-side-fallback-2026-07-01"],
        fallbacks: "default",
        output_config: {
          effort: "medium",
          format: { type: "json_schema", schema: MEAL_SCHEMA },
        },
        system: SYSTEM,
        messages: [
          {
            role: "user",
            content: [
              { type: "image", source: { type: "base64", media_type: "image/jpeg", data: image } },
              {
                type: "text",
                text: `Local time: ${localTime}.${note ? ` Note from the user: ${note}` : ""}\nWhat is in this meal?`,
              },
            ],
          },
        ],
      });

      if (response.stop_reason === "refusal") {
        return fail(422, "refused", "This photo couldn't be analysed. Try another one.");
      }
      if (response.stop_reason === "max_tokens") {
        return fail(502, "truncated", "The answer was cut off. Try again.");
      }
      const text = response.content.find((b) => b.type === "text");
      if (!text || text.type !== "text") return fail(502, "empty", "No answer came back. Try again.");
      return json(JSON.parse(text.text));
    } catch (error) {
      if (error instanceof Anthropic.RateLimitError) {
        return fail(503, "busy", "The service is busy. Try again in a moment.");
      }
      if (error instanceof Anthropic.BadRequestError) {
        return fail(400, "bad_image", "That photo couldn't be read. Try another one.");
      }
      if (error instanceof Anthropic.APIError) {
        return fail(502, "upstream", `Upstream error ${error.status ?? ""}. Try again.`);
      }
      if (error instanceof SyntaxError) {
        return fail(502, "bad_answer", "The answer wasn't readable. Try again.");
      }
      return fail(500, "internal", "Something went wrong. Try again.");
    }
  },
} satisfies ExportedHandler<Env>;
