import { type Address, type Chain } from 'viem';
import { baseSepolia } from 'viem/chains';

export interface ExecutorConfig {
  chain: Chain;
  rpcUrl: string;
  privateKey: `0x${string}`;
  contracts: {
    workflowRegistry: Address;
    executionEngine: Address;
    rewardManager: Address;
  };
  polling: {
    blockIntervalMs: number;
    scanIntervalMs: number;
  };
  gas: {
    profitabilityMultiplier: number;
    maxGasPrice: bigint;
  };
  executorIndex: number;
  totalExecutors: number;
}

export function loadConfig(): ExecutorConfig {
  return {
    chain: baseSepolia,
    rpcUrl: process.env.RPC_URL || 'https://sepolia.base.org',
    privateKey: (process.env.PRIVATE_KEY || '0x') as `0x${string}`,
    contracts: {
      workflowRegistry: (process.env.REGISTRY_ADDRESS || '0x') as Address,
      executionEngine: (process.env.ENGINE_ADDRESS || '0x') as Address,
      rewardManager: (process.env.REWARD_ADDRESS || '0x') as Address,
    },
    polling: {
      blockIntervalMs: Number(process.env.BLOCK_INTERVAL_MS || 2000),
      scanIntervalMs: Number(process.env.SCAN_INTERVAL_MS || 12000),
    },
    gas: {
      profitabilityMultiplier: Number(process.env.PROFITABILITY_MULTIPLIER || 1.2),
      maxGasPrice: BigInt(process.env.MAX_GAS_PRICE || 50000000000),
    },
    executorIndex: Number(process.env.EXECUTOR_INDEX || 0),
    totalExecutors: Number(process.env.TOTAL_EXECUTORS || 1),
  };
}
