import { describe, it, expect } from 'vitest';
import { parseEther } from 'viem';
import { WorkflowBuilder } from '../src/builder.js';
import { StepType } from '../src/types.js';

describe('WorkflowBuilder', () => {
  it('builds a workflow with contract call and delay', () => {
    const wf = new WorkflowBuilder()
      .name('Test Workflow')
      .rewardPerStep(parseEther('0.001'))
      .addContractCall({
        target: '0x1234567890123456789012345678901234567890',
        callData: '0xabcdef',
      })
      .addDelay(3600n)
      .build();

    expect(wf.name).toBe('Test Workflow');
    expect(wf.steps).toHaveLength(2);
    expect(wf.steps[0].type).toBe(StepType.CONTRACT_CALL);
    expect(wf.steps[1].type).toBe(StepType.DELAY);
    expect(wf.steps[1].delay).toBe(3600n);
    expect(wf.rewardPerStep).toBe(parseEther('0.001'));
  });

  it('throws without a name', () => {
    expect(() =>
      new WorkflowBuilder()
        .addDelay(100n)
        .build()
    ).toThrow('Workflow name is required');
  });

  it('throws without steps', () => {
    expect(() =>
      new WorkflowBuilder()
        .name('Empty')
        .build()
    ).toThrow('At least one step is required');
  });

  it('throws with >50 steps', () => {
    const builder = new WorkflowBuilder().name('Big');
    for (let i = 0; i < 51; i++) {
      builder.addDelay(1n);
    }
    expect(() => builder.build()).toThrow('Maximum 50 steps');
  });
});
