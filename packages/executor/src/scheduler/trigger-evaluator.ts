import { keccak256, encodePacked } from 'viem';
import type { Logger } from 'pino';
import type { WorkflowScanResult } from '../monitor/workflow-scanner.js';

export class TriggerEvaluator {
  constructor(
    private executorIndex: number,
    private totalExecutors: number,
    private logger: Logger,
  ) {}

  filterByPriority(
    workflows: WorkflowScanResult[],
    blockNumber: bigint,
  ): WorkflowScanResult[] {
    return workflows.filter((wf) => {
      const priority = this.calculatePriority(wf.workflowId, wf.currentStepIndex, blockNumber);
      const isOurs = priority === this.executorIndex;
      if (isOurs) {
        this.logger.debug({ workflowId: wf.workflowId.toString() }, 'Claimed workflow');
      }
      return isOurs;
    });
  }

  private calculatePriority(
    workflowId: bigint,
    stepIndex: bigint,
    blockNumber: bigint,
  ): number {
    if (this.totalExecutors <= 1) return 0;
    const hash = keccak256(
      encodePacked(['uint256', 'uint256', 'uint256'], [workflowId, stepIndex, blockNumber]),
    );
    return Number(BigInt(hash) % BigInt(this.totalExecutors));
  }
}
