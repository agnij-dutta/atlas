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
  const privateKey = process.env.PRIVATE_KEY;
  if (!privateKey || privateKey === '0x' || privateKey.length < 66) {
    throw new Error('PRIVATE_KEY env var is missing or invalid. Must be a 0x-prefixed 64-char hex string.');
  }
  const registry = process.env.REGISTRY_ADDRESS;
  const engine = process.env.ENGINE_ADDRESS;
  const reward = process.env.REWARD_ADDRESS;
  if (!registry || !engine || !reward || registry.length < 42) {
    throw new Error('Contract addresses (REGISTRY_ADDRESS, ENGINE_ADDRESS, REWARD_ADDRESS) must be set.');
  }

  return {
    chain: baseSepolia,
    rpcUrl: process.env.RPC_URL || 'https://sepolia.base.org',
    privateKey: privateKey as `0x${string}`,
    contracts: {
      workflowRegistry: registry as Address,
      executionEngine: engine as Address,
      rewardManager: reward as Address,
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
