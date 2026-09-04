import { config } from "../config.js";

const ENDPOINT = "https://api.openai.com/v1/chat/completions";

/**
 * SF Symbol names the model may choose from for key findings. Constraining this
 * to an enum is what keeps emoji out of the UI — the app renders symbols, not text.
 */
export const ALLOWED_SYMBOLS = [
  "chart.line.uptrend.xyaxis",
  "chart.line.downtrend.xyaxis",
  "chart.bar",
  "house",
  "key",
  "building.2",
  "person.3",
  "person.2.badge.gearshape",
  "dollarsign.circle",
  "banknote",
  "briefcase",
  "graduationcap",
  "books.vertical",
  "studentdesk",
  "signature",
  "exclamationmark.triangle",
  "arrow.up.right",
  "arrow.down.right",
  "arrow.right",
];

const SYSTEM_PROMPT = `You are CivicAI, a civic data intelligence assistant inside an iOS app.

Your role:
- Analyze the public datasets provided to you about one U.S. county.
- Explain trends and changes clearly, for a reader aged 14 and up.
- Never invent statistics. Every number you state must appear in the provided data.
- Distinguish what the data shows from what it might mean.

Hard rules:
- Use ONLY the metrics in the provided JSON. If the data needed to answer is not
  there, set data_available to false and say plainly that you could not find
  reliable public data for that question. Do not answer from memory.
- Never claim causation. Use "coincided with", "is associated with", "the data shows".
- Always name the years a number comes from (values are point-in-time estimates).
- Note that dollar figures are in the dollars of their own year and are not
  inflation-adjusted, whenever you compare dollars across years.
- Be concise: summary is 1-2 sentences, what_this_means is 2-3 short paragraphs at most.
- Stay politically neutral. Describe conditions; do not assign blame or endorse policy.
- used_metric_ids must list every metric id you actually referenced. The app builds
  the source list from it, so an id you did not use will mis-cite the answer.`;

const ASK_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: [
    "data_available",
    "summary",
    "key_findings",
    "what_this_means",
    "chart_metric_id",
    "used_metric_ids",
  ],
  properties: {
    data_available: {
      type: "boolean",
      description: "False if the provided data cannot answer the question.",
    },
    summary: { type: "string", description: "One or two sentence direct answer." },
    key_findings: {
      type: "array",
      maxItems: 4,
      items: {
        type: "object",
        additionalProperties: false,
        required: ["sf_symbol", "title", "value", "change", "metric_id"],
        properties: {
          sf_symbol: { type: "string", enum: ALLOWED_SYMBOLS },
          title: { type: "string", description: "What is being measured, e.g. Median home value." },
          value: {
            type: "string",
            description: "Formatted change across years, e.g. $245,000 (2013) → $315,000 (2023).",
          },
          change: { type: "string", description: "Short delta, e.g. +28.6% over 10 years." },
          metric_id: {
            type: ["string", "null"],
            description: "The metric id this finding came from, or null.",
          },
        },
      },
    },
    what_this_means: { type: "string" },
    chart_metric_id: {
      type: ["string", "null"],
      description: "The single metric id whose trend chart best supports the answer.",
    },
    used_metric_ids: { type: "array", items: { type: "string" } },
  },
};

const COMPARE_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["summary", "what_this_means", "used_metric_ids"],
  properties: {
    summary: { type: "string" },
    what_this_means: { type: "string" },
    used_metric_ids: { type: "array", items: { type: "string" } },
  },
};

async function callModel({ schemaName, schema, userContent, maxTokens = 900 }) {
  const res = await fetch(ENDPOINT, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${config.openaiKey}`,
    },
    body: JSON.stringify({
      model: config.openaiModel,
      temperature: 0.2,
      max_tokens: maxTokens,
      messages: [
        { role: "system", content: SYSTEM_PROMPT },
        { role: "user", content: userContent },
      ],
      response_format: {
        type: "json_schema",
        json_schema: { name: schemaName, strict: true, schema },
      },
    }),
  });

  if (!res.ok) {
    const body = await res.text().catch(() => "");
    const err = new Error(`OpenAI responded ${res.status}`);
    err.code = res.status === 429 ? "RATE_LIMIT" : "AI_UNAVAILABLE";
    // Logged server-side only — never returned to the client.
    console.error(`[openai] ${res.status}: ${body.slice(0, 500)}`);
    throw err;
  }

  const json = await res.json();
  const text = json.choices?.[0]?.message?.content;
  if (!text) {
    const err = new Error("OpenAI returned no content");
    err.code = "AI_UNAVAILABLE";
    throw err;
  }
  return JSON.parse(text);
}

export const analyzeQuestion = (question, context) =>
  callModel({
    schemaName: "civicai_answer",
    schema: ASK_SCHEMA,
    userContent: `Question: ${question}\n\nCounty data (JSON):\n${JSON.stringify(context)}`,
  });

export const analyzeComparison = (contextA, contextB) =>
  callModel({
    schemaName: "civicai_comparison",
    schema: COMPARE_SCHEMA,
    maxTokens: 700,
    userContent:
      `Compare these two counties neutrally. Describe the largest differences and ` +
      `what they do and do not tell us. Do not rank the places or call one better.\n\n` +
      `Location A (JSON):\n${JSON.stringify(contextA)}\n\n` +
      `Location B (JSON):\n${JSON.stringify(contextB)}`,
  });
