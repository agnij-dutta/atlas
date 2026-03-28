import type { Logger } from 'pino';

export interface WorkflowScanResult {
  workflowId: bigint;
  currentStepIndex: bigint;
  rewardPerStep: bigint;
}

export class WorkflowScanner {
  constructor(
    private registryContract: any,
    private engineContract: any,
    private logger: Logger,
  ) {}

  async scanActiveWorkflows(): Promise<WorkflowScanResult[]> {
    const ready: WorkflowScanResult[] = [];

    try {
      const count = await this.registryContract.read.workflowCount();
      this.logger.debug({ totalWorkflows: count }, 'Scanning workflows');

      for (let i = 1n; i <= count; i++) {
        try {
          const isReady = await this.engineContract.read.isStepReady([i]);
          if (isReady) {
            const wf = await this.registryContract.read.getWorkflow([i]);
            ready.push({
              workflowId: i,
              currentStepIndex: wf.currentStepIndex,
              rewardPerStep: wf.rewardPerStep,
            });
          }
        } catch (err: any) {
          // Only suppress "workflow not found" type errors, log real failures
          const msg = err?.message || '';
          if (!msg.includes('revert') && !msg.includes('out of range')) {
            this.logger.warn({ workflowId: i.toString(), err: msg }, 'Unexpected error checking workflow');
          }
        }
      }
    } catch (err) {
      this.logger.error({ err }, 'Failed to scan workflows');
    }

    this.logger.info({ readyCount: ready.length }, 'Scan complete');
    return ready;
  }
}
