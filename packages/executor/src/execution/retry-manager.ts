import type { Logger } from 'pino';

export class RetryManager {
  private retries = new Map<string, number>();
  private maxRetries = 3;
  private baseDelayMs = 1000;

  constructor(private logger: Logger) {}

  shouldRetry(key: string): boolean {
    const count = this.retries.get(key) || 0;
    return count < this.maxRetries;
  }

  async retry<T>(key: string, fn: () => Promise<T>): Promise<T | null> {
    const count = this.retries.get(key) || 0;
    if (count >= this.maxRetries) {
      this.logger.warn({ key, count }, 'Max retries exceeded');
      return null;
    }

    const delay = this.baseDelayMs * Math.pow(2, count);
    this.logger.debug({ key, attempt: count + 1, delay }, 'Retrying');
    await new Promise((r) => setTimeout(r, delay));

    try {
      const result = await fn();
      this.retries.delete(key);
      return result;
    } catch (err) {
      this.retries.set(key, count + 1);
      this.logger.error({ key, attempt: count + 1, err }, 'Retry failed');
      return null;
    }
  }

  clear(key: string): void {
    this.retries.delete(key);
  }
}
