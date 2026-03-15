import type { Address, Chain, WalletClient, PublicClient } from 'viem';

export enum WorkflowStatus {
  NONE = 0,
  ACTIVE = 1,
  PAUSED = 2,
  COMPLETED = 3,
  FAILED = 4,
}

export enum StepType {
  CONTRACT_CALL = 0,
  TOKEN_TRANSFER = 1,
  CONDITION_CHECK = 2,
  DELAY = 3,
}

export interface StepDefinition {
  type: StepType;
  target?: Address;
  callData?: `0x${string}`;
  value?: bigint;
  delay?: bigint;
  conditionData?: `0x${string}`;
}

export interface WorkflowDefinition {
  name: string;
  steps: StepDefinition[];
  rewardPerStep: bigint;
}

export interface AtlasClientConfig {
  chain: Chain;
  walletClient: WalletClient;
  publicClient: PublicClient;
  contracts: {
    workflowRegistry: Address;
    executionEngine: Address;
    rewardManager: Address;
  };
}

export interface WorkflowInfo {
  id: bigint;
  owner: Address;
  status: WorkflowStatus;
  currentStepIndex: number;
  totalSteps: number;
  rewardBalance: bigint;
  rewardPerStep: bigint;
  createdAt: bigint;
  lastExecutedAt: bigint;
}

export interface StepInfo {
  stepType: StepType;
  target: Address;
  callData: `0x${string}`;
  value: bigint;
  delay: bigint;
  conditionData: `0x${string}`;
}
