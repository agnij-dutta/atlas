import { type Address, encodeFunctionData, parseEther } from 'viem';
import { StepType, type StepDefinition, type WorkflowDefinition } from './types.js';

export class WorkflowBuilder {
  private _name = '';
  private _steps: StepDefinition[] = [];
  private _rewardPerStep = parseEther('0.001');

  name(name: string): this {
    this._name = name;
    return this;
  }

  rewardPerStep(amount: bigint): this {
    this._rewardPerStep = amount;
    return this;
  }

  addContractCall(params: {
    target: Address;
    callData: `0x${string}`;
    value?: bigint;
  }): this {
    this._steps.push({
      type: StepType.CONTRACT_CALL,
      target: params.target,
      callData: params.callData,
      value: params.value || 0n,
      delay: 0n,
      conditionData: '0x' as `0x${string}`,
    });
    return this;
  }

  addTokenTransfer(params: {
    target: Address;
    value: bigint;
  }): this {
    this._steps.push({
      type: StepType.TOKEN_TRANSFER,
      target: params.target,
      callData: '0x' as `0x${string}`,
      value: params.value,
      delay: 0n,
      conditionData: '0x' as `0x${string}`,
    });
    return this;
  }

  addDelay(seconds: bigint): this {
    this._steps.push({
      type: StepType.DELAY,
      target: '0x0000000000000000000000000000000000000000' as Address,
      callData: '0x' as `0x${string}`,
      value: 0n,
      delay: seconds,
      conditionData: '0x' as `0x${string}`,
    });
    return this;
  }

  addConditionCheck(params: {
    target: Address;
    conditionData: `0x${string}`;
  }): this {
    this._steps.push({
      type: StepType.CONDITION_CHECK,
      target: params.target,
      callData: '0x' as `0x${string}`,
      value: 0n,
      delay: 0n,
      conditionData: params.conditionData,
    });
    return this;
  }

  addStep(step: StepDefinition): this {
    this._steps.push(step);
    return this;
  }

  build(): WorkflowDefinition {
    if (!this._name) throw new Error('Workflow name is required');
    if (this._steps.length === 0) throw new Error('At least one step is required');
    if (this._steps.length > 50) throw new Error('Maximum 50 steps allowed');

    return {
      name: this._name,
      steps: [...this._steps],
      rewardPerStep: this._rewardPerStep,
    };
  }
}
