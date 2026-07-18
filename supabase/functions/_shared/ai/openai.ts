import { assessmentJsonSchema } from "./schema.ts";
import { systemPrompt } from "./prompt.ts";
import { validateAssessment } from "./validation.ts";
import type { ModelAssessment } from "./types.ts";

export interface AiProviderResult {
  assessment: ModelAssessment;
  responseId: string | null;
  model: string;
}

export class OpenAiAssessmentService {
  constructor(
    private readonly apiKey: string,
    private readonly model = "gpt-5.6-luna",
  ) {}

  async assess(
    prompt: string,
    safetyIdentifier: string,
  ): Promise<AiProviderResult> {
    let lastError: unknown;
    for (let attempt = 0; attempt < 3; attempt++) {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), 25_000);
      try {
        const response = await fetch("https://api.openai.com/v1/responses", {
          method: "POST",
          headers: {
            Authorization: `Bearer ${this.apiKey}`,
            "Content-Type": "application/json",
          },
          signal: controller.signal,
          body: JSON.stringify({
            model: this.model,
            instructions: systemPrompt,
            input: prompt,
            max_output_tokens: 3000,
            store: false,
            safety_identifier: safetyIdentifier,
            text: {
              format: {
                type: "json_schema",
                name: "fixbrief_repair_assessment",
                strict: true,
                schema: assessmentJsonSchema,
              },
            },
          }),
        });
        const payload = await response.json();
        if (!response.ok) {
          const message = payload?.error?.message ??
            `OpenAI returned ${response.status}.`;
          if (response.status !== 429 && response.status < 500) {
            throw new Error(message);
          }
          lastError = new Error(message);
        } else {
          const content = Array.isArray(payload.output)
            ? payload.output.flatMap((item: Record<string, unknown>) =>
              Array.isArray(item.content) ? item.content : []
            )
            : [];
          const refusal = content.find((item: Record<string, unknown>) =>
            item.type === "refusal"
          );
          if (refusal) {
            throw new Error("The AI provider declined this assessment.");
          }
          const output = content.find((item: Record<string, unknown>) =>
            item.type === "output_text"
          );
          if (!output || typeof output.text !== "string") {
            throw new Error(
              "The AI provider returned no structured assessment.",
            );
          }
          return {
            assessment: validateAssessment(JSON.parse(output.text)),
            responseId: typeof payload.id === "string" ? payload.id : null,
            model: this.model,
          };
        }
      } catch (error) {
        lastError = error;
      } finally {
        clearTimeout(timer);
      }
      if (attempt < 2) {
        await new Promise((resolve) =>
          setTimeout(resolve, 300 * (attempt + 1))
        );
      }
    }
    throw lastError instanceof Error
      ? lastError
      : new Error("AI provider failed.");
  }
}
