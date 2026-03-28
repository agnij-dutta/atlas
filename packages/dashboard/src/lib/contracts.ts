import { type Address } from 'viem';

export const CONTRACTS = {
  workflowRegistry: (process.env.NEXT_PUBLIC_REGISTRY_ADDRESS || '0xc17F81db41a12a396e54DA9694B323148c945117') as Address,
  executionEngine: (process.env.NEXT_PUBLIC_ENGINE_ADDRESS || '0xE8E045ad8332700E811f3424C0E902057BBd0dAE') as Address,
  rewardManager: (process.env.NEXT_PUBLIC_REWARD_ADDRESS || '0xe28489d7687b67EE99feBC81cd39331E29db4Ef2') as Address,
};

export const WORKFLOW_REGISTRY_ABI = [
  {
    name: 'createWorkflow',
    type: 'function' as const,
    stateMutability: 'payable' as const,
    inputs: [
      {
        name: 'steps',
        type: 'tuple[]' as const,
        components: [
          { name: 'stepType', type: 'uint8' as const },
          { name: 'target', type: 'address' as const },
          { name: 'callData', type: 'bytes' as const },
          { name: 'value', type: 'uint256' as const },
          { name: 'delay', type: 'uint256' as const },
          { name: 'conditionData', type: 'bytes' as const },
        ],
      },
      { name: 'rewardPerStep', type: 'uint256' as const },
    ],
    outputs: [{ name: '', type: 'uint256' as const }],
  },
  {
    name: 'pauseWorkflow',
    type: 'function' as const,
    stateMutability: 'nonpayable' as const,
    inputs: [{ name: 'workflowId', type: 'uint256' as const }],
    outputs: [],
  },
  {
    name: 'resumeWorkflow',
    type: 'function' as const,
    stateMutability: 'nonpayable' as const,
    inputs: [{ name: 'workflowId', type: 'uint256' as const }],
    outputs: [],
  },
  {
    name: 'cancelWorkflow',
    type: 'function' as const,
    stateMutability: 'nonpayable' as const,
    inputs: [{ name: 'workflowId', type: 'uint256' as const }],
    outputs: [],
  },
  {
    name: 'getWorkflow',
    type: 'function' as const,
    stateMutability: 'view' as const,
    inputs: [{ name: 'workflowId', type: 'uint256' as const }],
    outputs: [
      {
        name: '',
        type: 'tuple' as const,
        components: [
          { name: 'id', type: 'uint256' as const },
          { name: 'owner', type: 'address' as const },
          { name: 'status', type: 'uint8' as const },
          { name: 'currentStepIndex', type: 'uint256' as const },
          { name: 'totalSteps', type: 'uint256' as const },
          { name: 'rewardBalance', type: 'uint256' as const },
          { name: 'rewardPerStep', type: 'uint256' as const },
          { name: 'createdAt', type: 'uint256' as const },
          { name: 'lastExecutedAt', type: 'uint256' as const },
        ],
      },
    ],
  },
  {
    name: 'getSteps',
    type: 'function' as const,
    stateMutability: 'view' as const,
    inputs: [{ name: 'workflowId', type: 'uint256' as const }],
    outputs: [
      {
        name: '',
        type: 'tuple[]' as const,
        components: [
          { name: 'stepType', type: 'uint8' as const },
          { name: 'target', type: 'address' as const },
          { name: 'callData', type: 'bytes' as const },
          { name: 'value', type: 'uint256' as const },
          { name: 'delay', type: 'uint256' as const },
          { name: 'conditionData', type: 'bytes' as const },
        ],
      },
    ],
  },
  {
    name: 'workflowCount',
    type: 'function' as const,
    stateMutability: 'view' as const,
    inputs: [],
    outputs: [{ name: '', type: 'uint256' as const }],
  },
] as const;
