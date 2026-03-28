import type { PublicClient } from 'viem';
import type { Logger } from 'pino';

export interface GasEstimate {
  maxFeePerGas: bigint;
  maxPriorityFeePerGas: bigint;
  estimatedCost: bigint;
}

export class GasEstimator {
  constructor(
    private client: PublicClient,
    private maxGasPrice: bigint,
    private logger: Logger,
  ) {}

  async estimate(gasLimit: bigint): Promise<GasEstimate> {
    const block = await this.client.getBlock({ blockTag: 'latest' });
    const baseFee = block.baseFeePerGas || 0n;
    const maxPriorityFeePerGas = 1500000000n; // 1.5 gwei
    let maxFeePerGas = baseFee * 2n + maxPriorityFeePerGas;

    // Enforce the configured max gas price cap
    if (maxFeePerGas > this.maxGasPrice) {
      this.logger.warn({
        computed: maxFeePerGas.toString(),
        cap: this.maxGasPrice.toString(),
      }, 'Gas price exceeds cap, clamping');
      maxFeePerGas = this.maxGasPrice;
    }

    const estimatedCost = gasLimit * maxFeePerGas;

    this.logger.debug({
      baseFee: baseFee.toString(),
      maxFeePerGas: maxFeePerGas.toString(),
      estimatedCost: estimatedCost.toString(),
    }, 'Gas estimate');

    return { maxFeePerGas, maxPriorityFeePerGas, estimatedCost };
  }

  isProfitable(reward: bigint, gasCost: bigint, multiplier: number): boolean {
    const threshold = (gasCost * BigInt(Math.floor(multiplier * 100))) / 100n;
    return reward >= threshold;
  }
}
