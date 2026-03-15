import { BigInt, Bytes } from '@graphprotocol/graph-ts';
import {
  WorkflowCreated,
  WorkflowPaused,
  WorkflowResumed,
  WorkflowCancelled,
  WorkflowCompleted,
  WorkflowFailed,
} from '../generated/WorkflowRegistry/WorkflowRegistry';
import { Workflow, ProtocolStat } from '../generated/schema';

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

export function handleWorkflowCreated(event: WorkflowCreated): void {
  const id = event.params.workflowId.toString();
  const workflow = new Workflow(id);
  workflow.owner = event.params.owner;
  workflow.status = 'ACTIVE';
  workflow.totalSteps = event.params.totalSteps;
  workflow.currentStepIndex = BigInt.fromI32(0);
  workflow.rewardPerStep = event.params.rewardPerStep;
  workflow.createdAt = event.block.timestamp;
  workflow.createdAtBlock = event.block.number;
  workflow.updatedAt = event.block.timestamp;
  workflow.save();

  const stats = getOrCreateStats();
  stats.totalWorkflows = stats.totalWorkflows.plus(BigInt.fromI32(1));
  stats.activeWorkflows = stats.activeWorkflows.plus(BigInt.fromI32(1));
  stats.save();
}

export function handleWorkflowPaused(event: WorkflowPaused): void {
  const workflow = Workflow.load(event.params.workflowId.toString());
  if (workflow) {
    workflow.status = 'PAUSED';
    workflow.updatedAt = event.block.timestamp;
    workflow.save();

    const stats = getOrCreateStats();
    stats.activeWorkflows = stats.activeWorkflows.minus(BigInt.fromI32(1));
    stats.save();
  }
}

export function handleWorkflowResumed(event: WorkflowResumed): void {
  const workflow = Workflow.load(event.params.workflowId.toString());
  if (workflow) {
    workflow.status = 'ACTIVE';
    workflow.updatedAt = event.block.timestamp;
    workflow.save();

    const stats = getOrCreateStats();
    stats.activeWorkflows = stats.activeWorkflows.plus(BigInt.fromI32(1));
    stats.save();
  }
}

export function handleWorkflowCancelled(event: WorkflowCancelled): void {
  const workflow = Workflow.load(event.params.workflowId.toString());
  if (workflow) {
    workflow.status = 'CANCELLED';
    workflow.updatedAt = event.block.timestamp;
    workflow.save();

    const stats = getOrCreateStats();
    stats.activeWorkflows = stats.activeWorkflows.minus(BigInt.fromI32(1));
    stats.failedWorkflows = stats.failedWorkflows.plus(BigInt.fromI32(1));
    stats.save();
  }
}

export function handleWorkflowCompleted(event: WorkflowCompleted): void {
  const workflow = Workflow.load(event.params.workflowId.toString());
  if (workflow) {
    workflow.status = 'COMPLETED';
    workflow.updatedAt = event.block.timestamp;
    workflow.save();

    const stats = getOrCreateStats();
    stats.activeWorkflows = stats.activeWorkflows.minus(BigInt.fromI32(1));
    stats.completedWorkflows = stats.completedWorkflows.plus(BigInt.fromI32(1));
    stats.save();
  }
}

export function handleWorkflowFailed(event: WorkflowFailed): void {
  const workflow = Workflow.load(event.params.workflowId.toString());
  if (workflow) {
    workflow.status = 'FAILED';
    workflow.updatedAt = event.block.timestamp;
    workflow.save();

    const stats = getOrCreateStats();
    stats.activeWorkflows = stats.activeWorkflows.minus(BigInt.fromI32(1));
    stats.failedWorkflows = stats.failedWorkflows.plus(BigInt.fromI32(1));
    stats.save();
  }
}
