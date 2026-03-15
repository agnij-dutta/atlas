export interface ExecutorInfo {
  address: `0x${string}`;
  isActive: boolean;
  totalExecutions: bigint;
  totalRewards: bigint;
}
