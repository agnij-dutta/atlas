import { BigInt } from '@graphprotocol/graph-ts';
import { RewardClaimed } from '../generated/RewardManager/RewardManager';
import { StepExecution, Executor, ProtocolStat } from '../generated/schema';

export function handleRewardClaimed(event: RewardClaimed): void {
  const id = event.params.workflowId.toString() + '-' + event.params.stepIndex.toString();

  const execution = StepExecution.load(id);
  if (execution) {
    execution.reward = event.params.amount;
    execution.save();
  }

  // Update executor rewards
  let executor = Executor.load(event.params.executor.toHexString());
  if (executor) {
    executor.totalRewardsEarned = executor.totalRewardsEarned.plus(event.params.amount);
    executor.save();
  }

  // Update protocol stats
  let stats = ProtocolStat.load('global');
  if (stats) {
    stats.totalRewardsPaid = stats.totalRewardsPaid.plus(event.params.amount);
    stats.save();
  }
}
