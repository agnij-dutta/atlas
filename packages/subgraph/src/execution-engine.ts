import { BigInt } from '@graphprotocol/graph-ts';
import { StepExecuted, StepFailed } from '../generated/ExecutionEngine/ExecutionEngine';
import { StepExecution, Workflow, Executor, ProtocolStat } from '../generated/schema';

function getOrCreateExecutor(address: string): Executor {
  let executor = Executor.load(address);
  if (!executor) {
    executor = new Executor(address);
    executor.address = changetype<import("@graphprotocol/graph-ts").Bytes>(import("@graphprotocol/graph-ts").Address.fromString(address));
    executor.totalExecutions = BigInt.fromI32(0);
    executor.successfulExecutions = BigInt.fromI32(0);
    executor.failedExecutions = BigInt.fromI32(0);
    executor.totalRewardsEarned = BigInt.fromI32(0);
  }
  return executor;
}

function getOrCreateStats(): ProtocolStat {
  let stats = ProtocolStat.load('global');
  if (!stats) {
    stats = new ProtocolStat('global');
    stats.totalWorkflows = BigInt.fromI32(0);
    stats.activeWorkflows = BigInt.fromI32(0);
    stats.completedWorkflows = BigInt.fromI32(0);
    stats.failedWorkflows = BigInt.fromI32(0);
    stats.totalExecutions = BigInt.fromI32(0);
    stats.totalRewardsPaid = BigInt.fromI32(0);
  }
  return stats;
}

export function handleStepExecuted(event: StepExecuted): void {
  const id = event.params.workflowId.toString() + '-' + event.params.stepIndex.toString();

  const execution = new StepExecution(id);
  execution.workflow = event.params.workflowId.toString();
  execution.stepIndex = event.params.stepIndex;
  execution.executor = event.params.executor.toHexString();
  execution.success = true;
  execution.gasUsed = event.params.gasUsed;
  execution.reward = BigInt.fromI32(0); // Updated by RewardClaimed
  execution.timestamp = event.block.timestamp;
  execution.blockNumber = event.block.number;
  execution.txHash = event.transaction.hash;
  execution.save();

  // Update workflow
  const workflow = Workflow.load(event.params.workflowId.toString());
  if (workflow) {
    workflow.currentStepIndex = event.params.stepIndex.plus(BigInt.fromI32(1));
    workflow.updatedAt = event.block.timestamp;
    workflow.save();
  }

  // Update executor
  const executor = getOrCreateExecutor(event.params.executor.toHexString());
  executor.totalExecutions = executor.totalExecutions.plus(BigInt.fromI32(1));
  executor.successfulExecutions = executor.successfulExecutions.plus(BigInt.fromI32(1));
  executor.save();

  // Update stats
  const stats = getOrCreateStats();
  stats.totalExecutions = stats.totalExecutions.plus(BigInt.fromI32(1));
  stats.save();
}

export function handleStepFailed(event: StepFailed): void {
  const id = event.params.workflowId.toString() + '-' + event.params.stepIndex.toString();

  const execution = new StepExecution(id);
  execution.workflow = event.params.workflowId.toString();
  execution.stepIndex = event.params.stepIndex;
  execution.executor = event.transaction.from.toHexString();
  execution.success = false;
  execution.gasUsed = BigInt.fromI32(0);
  execution.reward = BigInt.fromI32(0);
  execution.timestamp = event.block.timestamp;
  execution.blockNumber = event.block.number;
  execution.txHash = event.transaction.hash;
  execution.save();

  // Update executor
  const executor = getOrCreateExecutor(event.transaction.from.toHexString());
  executor.totalExecutions = executor.totalExecutions.plus(BigInt.fromI32(1));
  executor.failedExecutions = executor.failedExecutions.plus(BigInt.fromI32(1));
  executor.save();
}
