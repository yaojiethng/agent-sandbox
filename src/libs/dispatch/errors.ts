/**
 * The dispatch seam's error vocabulary. A refusal is one message and one exit
 * code, so the renderer in the entrypoint reads the code off the error rather
 * than off a per-call-site branch.
 */
export class DispatchError extends Error {
  readonly code: number;

  constructor(message: string, code = 1) {
    super(message);
    this.code = code;
  }
}

/** A malformed invocation, which the seam reports with exit 2. */
export class UsageError extends DispatchError {
  constructor(message: string) {
    super(message, 2);
  }
}
