export enum StepType {
  CONTRACT_CALL = 0,
  TOKEN_TRANSFER = 1,
  CONDITION_CHECK = 2,
  DELAY = 3,
}

export interface Step {
  stepType: StepType;
  target: `0x${string}`;
  callData: `0x${string}`;
  value: bigint;
  delay: bigint;
  conditionData: `0x${string}`;
}
