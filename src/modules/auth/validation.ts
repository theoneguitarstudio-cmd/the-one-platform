import { z } from "zod";

export const emailSchema = z.email().trim().toLowerCase();

export const passwordSchema = z
  .string()
  .min(12)
  .max(128)
  .regex(/[A-Za-z]/)
  .regex(/[0-9]/);

export const signUpSchema = z.object({
  displayName: z.string().trim().min(2).max(80),
  email: emailSchema,
  password: passwordSchema,
});

export const signInSchema = z.object({
  email: emailSchema,
  password: z.string().min(1).max(128),
});
