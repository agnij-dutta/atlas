import { describe, it, expect, vi } from 'vitest';
import { TriggerEvaluator } from '../src/scheduler/trigger-evaluator.js';

const mockLogger = { debug: vi.fn(), info: vi.fn(), warn: vi.fn(), error: vi.fn() } as any;

describe('TriggerEvaluator', () => {
  it('claims all workflows when totalExecutors is 1', () => {
    const evaluator = new TriggerEvaluator(0, 1, mockLogger);
    const workflows = [
      { workflowId: 1n, currentStepIndex: 0n, rewardPerStep: 1000n },
      { workflowId: 2n, currentStepIndex: 1n, rewardPerStep: 2000n },
    ];
    const result = evaluator.filterByPriority(workflows, 100n);
    expect(result).toHaveLength(2);
  });

  it('filters workflows deterministically with multiple executors', () => {
    const evaluator0 = new TriggerEvaluator(0, 3, mockLogger);
    const evaluator1 = new TriggerEvaluator(1, 3, mockLogger);
    const evaluator2 = new TriggerEvaluator(2, 3, mockLogger);

    const workflows = [
      { workflowId: 1n, currentStepIndex: 0n, rewardPerStep: 1000n },
      { workflowId: 2n, currentStepIndex: 0n, rewardPerStep: 1000n },
      { workflowId: 3n, currentStepIndex: 0n, rewardPerStep: 1000n },
    ];

    const block = 100n;
    const r0 = evaluator0.filterByPriority(workflows, block);
    const r1 = evaluator1.filterByPriority(workflows, block);
    const r2 = evaluator2.filterByPriority(workflows, block);

    // Every workflow should be claimed by exactly one executor
    const totalClaimed = r0.length + r1.length + r2.length;
    expect(totalClaimed).toBe(3);
  });

  it('returns consistent results for same inputs', () => {
    const evaluator = new TriggerEvaluator(0, 2, mockLogger);
    const workflows = [{ workflowId: 42n, currentStepIndex: 5n, rewardPerStep: 1000n }];
    const r1 = evaluator.filterByPriority(workflows, 200n);
    const r2 = evaluator.filterByPriority(workflows, 200n);
    expect(r1.length).toBe(r2.length);
  });
});
