export enum WorkflowStatus {
  NONE = 0,
  ACTIVE = 1,
  PAUSED = 2,
  COMPLETED = 3,
  FAILED = 4,
}

export interface Workflow {
  id: bigint;
  owner: `0x${string}`;
  status: WorkflowStatus;
  currentStepIndex: number;
  totalSteps: number;
  rewardBalance: bigint;
  rewardPerStep: bigint;
  createdAt: bigint;
  lastExecutedAt: bigint;
}
