export const ATLAS_CONTRACTS = {
  baseSepolia: {
    workflowRegistry: '0xc17F81db41a12a396e54DA9694B323148c945117' as `0x${string}`,
    executionEngine: '0xE8E045ad8332700E811f3424C0E902057BBd0dAE' as `0x${string}`,
    rewardManager: '0xe28489d7687b67EE99feBC81cd39331E29db4Ef2' as `0x${string}`,
  },
} as const;

export const BASE_SEPOLIA_CHAIN_ID = 84532;
export const MIN_REWARD_PER_STEP = 100000000000000n; // 0.0001 ETH
export const EXECUTOR_SELECTION_WINDOW = 2; // blocks
export const GAS_PROFITABILITY_MULTIPLIER = 1.2;
