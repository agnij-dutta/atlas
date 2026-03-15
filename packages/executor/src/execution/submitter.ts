import type { WalletClient, PublicClient, Address, Hash } from 'viem';
import type { Logger } from 'pino';
import type { GasEstimate } from '../gas/gas-estimator.js';
import { NonceManager } from '../nonce/nonce-manager.js';

export class Submitter {
  private nonceManager: NonceManager;

  constructor(
    private walletClient: WalletClient,
    private publicClient: PublicClient,
    private engineAddress: Address,
    private logger: Logger,
  ) {
    this.nonceManager = new NonceManager(publicClient, walletClient.account!.address, logger);
  }

  async submitExecution(
    workflowId: bigint,
    gasEstimate: GasEstimate,
  ): Promise<Hash | null> {
    try {
      const nonce = await this.nonceManager.getNextNonce();

      const hash = await this.walletClient.sendTransaction({
        to: this.engineAddress,
        data: this.encodeExecuteStep(workflowId),
        maxFeePerGas: gasEstimate.maxFeePerGas,
        maxPriorityFeePerGas: gasEstimate.maxPriorityFeePerGas,
        nonce,
      });

      this.logger.info({ workflowId: workflowId.toString(), hash }, 'Transaction submitted');
      return hash;
    } catch (err) {
      this.logger.error({ workflowId: workflowId.toString(), err }, 'Submission failed');
      this.nonceManager.reset();
      return null;
    }
  }

  async waitForConfirmation(hash: Hash): Promise<boolean> {
    try {
      const receipt = await this.publicClient.waitForTransactionReceipt({ hash, confirmations: 1 });
      const success = receipt.status === 'success';
      this.logger.info({ hash, status: receipt.status, gasUsed: receipt.gasUsed.toString() }, 'Transaction confirmed');
      return success;
    } catch (err) {
      this.logger.error({ hash, err }, 'Confirmation failed');
      return false;
    }
  }

  private encodeExecuteStep(workflowId: bigint): `0x${string}` {
    const selector = '0x1c5f1452';
    const encoded = workflowId.toString(16).padStart(64, '0');
    return `${selector}${encoded}` as `0x${string}`;
  }
}
