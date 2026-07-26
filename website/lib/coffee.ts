// Single source of truth for the "Buy me a coffee" tip jar.
// Shared by the checkout API route and the dialog UI — do not hardcode
// amounts in components.

/** Preset tip amounts in cents; COFFEE_DEFAULT_AMOUNT_CENTS is preselected. */
export const COFFEE_PRESET_AMOUNTS_CENTS = [300, 500, 1000, 2000] as const;
export const COFFEE_DEFAULT_AMOUNT_CENTS = 500; // $5 default
export const COFFEE_MIN_CENTS = 100; // $1 floor for custom tips
export const COFFEE_MAX_CENTS = 50000; // $500 ceiling for custom tips

/** Whole-number-of-cents integer within the coffee bounds. */
export function validateCoffeeAmountCents(
  amountCents: number,
): { ok: true } | { ok: false; reason: string } {
  if (!Number.isInteger(amountCents)) {
    return { ok: false, reason: 'amount must be a whole number of cents' };
  }
  if (amountCents < COFFEE_MIN_CENTS || amountCents > COFFEE_MAX_CENTS) {
    return {
      ok: false,
      reason: `amount must be between ${COFFEE_MIN_CENTS} and ${COFFEE_MAX_CENTS} cents`,
    };
  }
  return { ok: true };
}
