import { type Address, type PublicClient, type WalletClient, getContract } from 'viem';
import type { ExecutorConfig } from '../config/index.js';

// Minimal ABIs for the functions we need
const EXECUTION_ENGINE_ABI = [
  {
    name: 'executeStep',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'workflowId', type: 'uint256' }],
    outputs: [],
  },
  {
    name: 'isStepReady',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'workflowId', type: 'uint256' }],
    outputs: [{ name: '', type: 'bool' }],
  },
] as const;

const WORKFLOW_REGISTRY_ABI = [
  {
    name: 'getWorkflow',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'workflowId', type: 'uint256' }],
    outputs: [
      {
        name: '',
        type: 'tuple',
        components: [
          { name: 'id', type: 'uint256' },
          { name: 'owner', type: 'address' },
          { name: 'status', type: 'uint8' },
          { name: 'currentStepIndex', type: 'uint256' },
          { name: 'totalSteps', type: 'uint256' },
          { name: 'rewardBalance', type: 'uint256' },
          { name: 'rewardPerStep', type: 'uint256' },
          { name: 'createdAt', type: 'uint256' },
          { name: 'lastExecutedAt', type: 'uint256' },
        ],
      },
    ],
  },
  {
    name: 'workflowCount',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'uint256' }],
  },
  {
    name: 'WorkflowCreated',
    type: 'event',
    inputs: [
      { name: 'workflowId', type: 'uint256', indexed: true },
      { name: 'owner', type: 'address', indexed: true },
      { name: 'totalSteps', type: 'uint256', indexed: false },
      { name: 'rewardPerStep', type: 'uint256', indexed: false },
    ],
  },
  {
    name: 'StepExecuted',
    type: 'event',
    inputs: [
      { name: 'workflowId', type: 'uint256', indexed: true },
      { name: 'stepIndex', type: 'uint256', indexed: true },
      { name: 'executor', type: 'address', indexed: true },
      { name: 'gasUsed', type: 'uint256', indexed: false },
    ],
  },
] as const;

export function createContracts(
  config: ExecutorConfig,
  publicClient: PublicClient,
  walletClient: WalletClient,
) {
  const engine = getContract({
    address: config.contracts.executionEngine,
    abi: EXECUTION_ENGINE_ABI,
    client: { public: publicClient, wallet: walletClient },
  });

  const registry = getContract({
    address: config.contracts.workflowRegistry,
    abi: WORKFLOW_REGISTRY_ABI,
    client: { public: publicClient, wallet: walletClient },
  });

  return { engine, registry };
}
