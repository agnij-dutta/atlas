export const WORKFLOW_REGISTRY_ABI = [
  {
    name: 'createWorkflow',
    type: 'function',
    stateMutability: 'payable',
    inputs: [
      {
        name: 'steps',
        type: 'tuple[]',
        components: [
          { name: 'stepType', type: 'uint8' },
          { name: 'target', type: 'address' },
          { name: 'callData', type: 'bytes' },
          { name: 'value', type: 'uint256' },
          { name: 'delay', type: 'uint256' },
          { name: 'conditionData', type: 'bytes' },
        ],
      },
      { name: 'rewardPerStep', type: 'uint256' },
    ],
    outputs: [{ name: '', type: 'uint256' }],
  },
  {
    name: 'pauseWorkflow',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'workflowId', type: 'uint256' }],
    outputs: [],
  },
  {
    name: 'resumeWorkflow',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'workflowId', type: 'uint256' }],
    outputs: [],
  },
  {
    name: 'cancelWorkflow',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'workflowId', type: 'uint256' }],
    outputs: [],
  },
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
    name: 'getSteps',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'workflowId', type: 'uint256' }],
    outputs: [
      {
        name: '',
        type: 'tuple[]',
        components: [
          { name: 'stepType', type: 'uint8' },
          { name: 'target', type: 'address' },
          { name: 'callData', type: 'bytes' },
          { name: 'value', type: 'uint256' },
          { name: 'delay', type: 'uint256' },
          { name: 'conditionData', type: 'bytes' },
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
] as const;

export const EXECUTION_ENGINE_ABI = [
  {
    name: 'isStepReady',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'workflowId', type: 'uint256' }],
    outputs: [{ name: '', type: 'bool' }],
  },
] as const;
