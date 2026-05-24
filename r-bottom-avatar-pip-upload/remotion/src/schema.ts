import { z } from "zod";

/**
 * A single "beat" of the topic b-roll. One beat == one animated scene.
 *  - text:            the spoken phrase / headline shown big in the safe zone
 *  - keywords:        short tokens revealed as accent chips (the "topic match")
 *  - durationInFrames: how long this beat holds on screen (at 30fps)
 */
export const beatSchema = z.object({
  text: z.string(),
  keywords: z.array(z.string()).default([]),
  durationInFrames: z.number().int().positive().default(90),
});

export const topicBrollSchema = z.object({
  /** Ordered list of beats. Total composition length == sum of durationInFrames. */
  beats: z.array(beatSchema).min(1),
  /** Brand palette — sensible Mr Growth Guide defaults baked in. */
  bgColor: z.string().default("#0F172A"),
  accentColor: z.string().default("#38BDF8"),
  textColor: z.string().default("#F8FAFC"),
  /** Show a faint footer label (brand handle) in the safe zone. */
  brandLabel: z.string().default("MR GROWTH GUIDE"),
});

export type Beat = z.infer<typeof beatSchema>;
export type TopicBrollProps = z.infer<typeof topicBrollSchema>;

export const FPS = 30;
export const WIDTH = 1080;
export const HEIGHT = 1920;
/** Avatar PIP occupies the bottom 540px (y=1380..1920). Keep visuals above this. */
export const SAFE_BOTTOM = 1380;
