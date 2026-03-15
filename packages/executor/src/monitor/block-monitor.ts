import type { PublicClient } from 'viem';
import type { Logger } from 'pino';

export class BlockMonitor {
  private unwatch: (() => void) | null = null;
  private latestBlock = 0n;

  constructor(
    private client: PublicClient,
    private logger: Logger,
  ) {}

  async start(onBlock: (blockNumber: bigint) => void): Promise<void> {
    this.latestBlock = await this.client.getBlockNumber();
    this.logger.info({ block: this.latestBlock }, 'Starting block monitor');

    this.unwatch = this.client.watchBlockNumber({
      onBlockNumber: (blockNumber) => {
        this.latestBlock = blockNumber;
        this.logger.debug({ block: blockNumber }, 'New block');
        onBlock(blockNumber);
      },
    });
  }

  stop(): void {
    this.unwatch?.();
    this.unwatch = null;
  }

  getLatestBlock(): bigint {
    return this.latestBlock;
  }
}
