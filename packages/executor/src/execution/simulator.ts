import type { PublicClient, Address } from 'viem';
import type { Logger } from 'pino';

export class Simulator {
  constructor(
    private client: PublicClient,
    private engineAddress: Address,
    private logger: Logger,
  ) {}

  async simulate(workflowId: bigint, account: Address): Promise<{ success: boolean; gasEstimate: bigint }> {
    try {
      const gasEstimate = await this.client.estimateGas({
        account,
        to: this.engineAddress,
        data: this.encodeExecuteStep(workflowId),
      });

      this.logger.debug({ workflowId: workflowId.toString(), gasEstimate: gasEstimate.toString() }, 'Simulation passed');
      return { success: true, gasEstimate };
    } catch (err) {
      this.logger.warn({ workflowId: workflowId.toString(), err }, 'Simulation failed');
      return { success: false, gasEstimate: 0n };
    }
  }

  private encodeExecuteStep(workflowId: bigint): `0x${string}` {
    // executeStep(uint256) selector: keccak256("executeStep(uint256)")[:4]
    const selector = '0x1c5f1452';
    const encoded = workflowId.toString(16).padStart(64, '0');
    return `${selector}${encoded}` as `0x${string}`;
  }
}
