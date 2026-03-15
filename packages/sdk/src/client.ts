import { getContract } from 'viem';
import type {
  AtlasClientConfig,
  WorkflowDefinition,
  WorkflowInfo,
  StepInfo,
} from './types.js';
import { WorkflowStatus } from './types.js';
import { WORKFLOW_REGISTRY_ABI, EXECUTION_ENGINE_ABI } from './abi.js';

export class AtlasClient {
  private registry;
  private engine;
  private config: AtlasClientConfig;

  constructor(config: AtlasClientConfig) {
    this.config = config;

    this.registry = getContract({
      address: config.contracts.workflowRegistry,
      abi: WORKFLOW_REGISTRY_ABI,
      client: { public: config.publicClient, wallet: config.walletClient },
    });

    this.engine = getContract({
      address: config.contracts.executionEngine,
      abi: EXECUTION_ENGINE_ABI,
      client: { public: config.publicClient },
    });
  }

  async createWorkflow(workflow: WorkflowDefinition): Promise<{ workflowId: bigint; hash: `0x${string}` }> {
    const totalDeposit = workflow.rewardPerStep * BigInt(workflow.steps.length);

    const steps = workflow.steps.map((s) => ({
      stepType: s.type,
      target: s.target || '0x0000000000000000000000000000000000000000' as `0x${string}`,
      callData: s.callData || '0x' as `0x${string}`,
      value: s.value || 0n,
      delay: s.delay || 0n,
      conditionData: s.conditionData || '0x' as `0x${string}`,
    }));

    const hash = await this.registry.write.createWorkflow([steps, workflow.rewardPerStep], {
      value: totalDeposit,
      account: this.config.walletClient.account!,
      chain: this.config.chain,
    } as any);

    // Get workflowId from the event logs
    const receipt = await this.config.publicClient.waitForTransactionReceipt({ hash });
    const workflowId = BigInt(receipt.logs[0]?.topics[1] || '0');

    return { workflowId, hash };
  }

  async pauseWorkflow(workflowId: bigint): Promise<`0x${string}`> {
    return this.registry.write.pauseWorkflow([workflowId], {
      account: this.config.walletClient.account!,
      chain: this.config.chain,
    } as any);
  }

  async resumeWorkflow(workflowId: bigint): Promise<`0x${string}`> {
    return this.registry.write.resumeWorkflow([workflowId], {
      account: this.config.walletClient.account!,
      chain: this.config.chain,
    } as any);
  }

  async cancelWorkflow(workflowId: bigint): Promise<`0x${string}`> {
    return this.registry.write.cancelWorkflow([workflowId], {
      account: this.config.walletClient.account!,
      chain: this.config.chain,
    } as any);
  }

  async getWorkflow(workflowId: bigint): Promise<WorkflowInfo> {
    const wf = await this.registry.read.getWorkflow([workflowId]);
    return {
      id: wf.id,
      owner: wf.owner,
      status: Number(wf.status) as WorkflowStatus,
      currentStepIndex: Number(wf.currentStepIndex),
      totalSteps: Number(wf.totalSteps),
      rewardBalance: wf.rewardBalance,
      rewardPerStep: wf.rewardPerStep,
      createdAt: wf.createdAt,
      lastExecutedAt: wf.lastExecutedAt,
    };
  }

  async getSteps(workflowId: bigint): Promise<StepInfo[]> {
    const steps = await this.registry.read.getSteps([workflowId]);
    return steps.map((s: any) => ({
      stepType: Number(s.stepType),
      target: s.target,
      callData: s.callData,
      value: s.value,
      delay: s.delay,
      conditionData: s.conditionData,
    }));
  }

  async getWorkflowCount(): Promise<bigint> {
    return this.registry.read.workflowCount();
  }

  async isStepReady(workflowId: bigint): Promise<boolean> {
    return this.engine.read.isStepReady([workflowId]);
  }
}
