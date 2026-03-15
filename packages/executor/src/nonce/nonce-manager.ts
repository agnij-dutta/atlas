import type { PublicClient, Address } from 'viem';
import type { Logger } from 'pino';

export class NonceManager {
  private currentNonce: number | null = null;

  constructor(
    private client: PublicClient,
    private address: Address,
    private logger: Logger,
  ) {}

  async getNextNonce(): Promise<number> {
    if (this.currentNonce === null) {
      this.currentNonce = await this.client.getTransactionCount({ address: this.address });
    } else {
      this.currentNonce++;
    }
    this.logger.debug({ nonce: this.currentNonce }, 'Nonce assigned');
    return this.currentNonce;
  }

  reset(): void {
    this.currentNonce = null;
    this.logger.debug('Nonce manager reset');
  }
}
