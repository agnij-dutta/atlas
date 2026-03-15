export const ATLAS_CONTRACTS = {
  baseSepolia: {
    workflowRegistry: '0x0000000000000000000000000000000000000000' as `0x${string}`,
    executionEngine: '0x0000000000000000000000000000000000000000' as `0x${string}`,
    rewardManager: '0x0000000000000000000000000000000000000000' as `0x${string}`,
  },
} as const;

export const BASE_SEPOLIA_CHAIN_ID = 84532;
export const MIN_REWARD_PER_STEP = 100000000000000n; // 0.0001 ETH
export const EXECUTOR_SELECTION_WINDOW = 2; // blocks
export const GAS_PROFITABILITY_MULTIPLIER = 1.2;
