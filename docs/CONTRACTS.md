# Atlas Protocol --- Contract Reference

> Complete reference for all deployed Solidity contracts, including
> functions, events, errors, types, and libraries.

**Compiler:** Solidity ^0.8.24
**Framework:** Foundry
**Network:** Base Sepolia (chain ID 84532)
**License:** MIT

---

## Table of Contents

1. [DataTypes](#datatypes)
2. [WorkflowRegistry](#workflowregistry)
3. [ExecutionEngine](#executionengine)
4. [RewardManager](#rewardmanager)
5. [StepExecutors](#stepexecutors)
6. [AtlasAccessControl](#atlasaccesscontrol)
7. [WorkflowLib](#workflowlib)
8. [StepLib](#steplib)
9. [TimeTriggerLib](#timetriggerlib)

---

## DataTypes

`packages/contracts/src/types/DataTypes.sol`

Shared type definitions used across all contracts.

### Enums

#### WorkflowStatus

```solidity
enum WorkflowStatus {
    NONE,       // 0 - Does not exist
    ACTIVE,     // 1 - Accepting executions
    PAUSED,     // 2 - Temporarily halted by owner
    COMPLETED,  // 3 - All steps executed
    FAILED      // 4 - Step failed or owner cancelled
}
```

#### StepType

```solidity
enum StepType {
    CONTRACT_CALL,    // 0 - Arbitrary external call
    TOKEN_TRANSFER,   // 1 - Native ETH transfer
    CONDITION_CHECK,  // 2 - Read-only check, must return true
    DELAY             // 3 - Time-based delay gate
}
```

### Structs

#### Workflow

```solidity
struct Workflow {
    uint256 id;                // Unique workflow identifier (starts at 1)
    address owner;             // Address that created the workflow
    WorkflowStatus status;     // Current lifecycle state
    uint256 currentStepIndex;  // Next step to execute (0-indexed)
    uint256 totalSteps;        // Total number of steps
    uint256 rewardBalance;     // Remaining ETH for executor rewards
    uint256 rewardPerStep;     // ETH paid per successful step execution
    uint256 createdAt;         // block.timestamp at creation
    uint256 lastExecutedAt;    // block.timestamp of last step execution
}
```

#### Step

```solidity
struct Step {
    StepType stepType;     // Execution type
    address target;        // Target contract address
    bytes callData;        // Encoded function call (for CONTRACT_CALL)
    uint256 value;         // ETH value to send with the call
    uint256 delay;         // Minimum seconds since last execution (for DELAY type)
    bytes conditionData;   // Encoded call for CONDITION_CHECK
}
```

#### StepExecutionResult

```solidity
struct StepExecutionResult {
    bool success;        // Whether the step succeeded
    bytes returnData;    // Raw return data from the call
    uint256 gasUsed;     // Gas consumed by the step execution
}
```

---

## WorkflowRegistry

`packages/contracts/src/core/WorkflowRegistry.sol`

**Address:** `0xc17F81db41a12a396e54DA9694B323148c945117`
**Inherits:** `IWorkflowRegistry`, `AtlasAccessControl`
**Uses:** `WorkflowLib` for `DataTypes.Workflow`

The central registry that stores all workflow definitions and step
data. Holds deposited ETH for executor rewards.

### Constants

| Name                | Type      | Value          | Description                     |
|---------------------|-----------|----------------|---------------------------------|
| `MAX_STEPS`         | `uint256` | `50`           | Maximum steps per workflow      |
| `MIN_REWARD_PER_STEP` | `uint256` | `0.0001 ether` | Minimum reward per step (100000000000000 wei) |

### State Variables

| Name              | Type                                     | Visibility | Description                  |
|-------------------|------------------------------------------|------------|------------------------------|
| `_nextWorkflowId` | `uint256`                                | private    | Auto-incrementing ID counter |
| `_workflows`      | `mapping(uint256 => DataTypes.Workflow)` | private    | Workflow ID to Workflow data |
| `_steps`          | `mapping(uint256 => DataTypes.Step[])`   | private    | Workflow ID to Step array    |

### Functions

#### initialize

```solidity
function initialize(address owner_) external initializer
```

UUPS initializer. Sets the contract owner and initializes
`_nextWorkflowId` to 1. Called once at proxy deployment.

**Parameters:**

| Name     | Type      | Description               |
|----------|-----------|---------------------------|
| `owner_` | `address` | Initial contract owner    |

---

#### createWorkflow

```solidity
function createWorkflow(
    DataTypes.Step[] calldata steps,
    uint256 rewardPerStep
) external payable returns (uint256)
```

Creates a new workflow with the provided steps. The caller must send
ETH equal to or exceeding `rewardPerStep * steps.length`.

**Parameters:**

| Name            | Type              | Description                                |
|-----------------|-------------------|--------------------------------------------|
| `steps`         | `Step[] calldata` | Ordered array of steps to execute          |
| `rewardPerStep` | `uint256`         | ETH reward per step (wei)                  |

**Returns:** `uint256` --- the newly assigned workflow ID.

**Reverts:**

| Error               | Condition                                    |
|---------------------|----------------------------------------------|
| `NoSteps`           | `steps.length == 0`                          |
| `TooManySteps`      | `steps.length > MAX_STEPS`                   |
| `InvalidReward`     | `rewardPerStep < MIN_REWARD_PER_STEP`        |
| `InsufficientDeposit` | `msg.value < rewardPerStep * steps.length` |
| `StepLib.InvalidTarget` | Step target is `address(0)` for call types |

**Emits:** `WorkflowCreated(workflowId, msg.sender, steps.length, rewardPerStep)`

---

#### pauseWorkflow

```solidity
function pauseWorkflow(uint256 workflowId) external
```

Pauses an active workflow. No steps can be executed until resumed.

**Parameters:**

| Name         | Type      | Description          |
|--------------|-----------|----------------------|
| `workflowId` | `uint256` | The workflow to pause |

**Reverts:**

| Error                          | Condition                 |
|--------------------------------|---------------------------|
| `WorkflowLib.NotWorkflowOwner` | Caller is not the owner  |
| `WorkflowLib.WorkflowNotActive` | Workflow is not active  |

**Emits:** `WorkflowPaused(workflowId)`

---

#### resumeWorkflow

```solidity
function resumeWorkflow(uint256 workflowId) external
```

Resumes a paused workflow back to active status.

**Parameters:**

| Name         | Type      | Description           |
|--------------|-----------|-----------------------|
| `workflowId` | `uint256` | The workflow to resume |

**Reverts:**

| Error                           | Condition                |
|---------------------------------|--------------------------|
| `WorkflowLib.NotWorkflowOwner`  | Caller is not the owner  |
| `WorkflowLib.WorkflowNotPaused` | Workflow is not paused   |

**Emits:** `WorkflowResumed(workflowId)`

---

#### cancelWorkflow

```solidity
function cancelWorkflow(uint256 workflowId) external
```

Cancels a workflow and refunds the remaining reward balance to the
owner. Sets status to `FAILED`.

**Parameters:**

| Name         | Type      | Description            |
|--------------|-----------|------------------------|
| `workflowId` | `uint256` | The workflow to cancel  |

**Reverts:**

| Error                                 | Condition                     |
|---------------------------------------|-------------------------------|
| `WorkflowLib.NotWorkflowOwner`        | Caller is not the owner       |
| `WorkflowLib.WorkflowAlreadyCompleted` | Workflow already completed   |
| `RefundFailed`                         | ETH refund transfer failed   |

**Emits:** `WorkflowCancelled(workflowId, refundAmount)`

---

#### advanceWorkflow

```solidity
function advanceWorkflow(uint256 workflowId) external onlyExecutor
```

Advances the workflow to the next step. If the final step was just
completed, sets status to `COMPLETED`. Called by `ExecutionEngine`
after a successful step execution.

**Access:** `onlyExecutor`

**Emits:** `WorkflowCompleted(workflowId)` if final step.

---

#### failWorkflow

```solidity
function failWorkflow(uint256 workflowId, uint256 stepIndex) external onlyExecutor
```

Marks a workflow as `FAILED` after a step execution failure.

**Access:** `onlyExecutor`

**Emits:** `WorkflowFailed(workflowId, stepIndex)`

---

#### deductReward

```solidity
function deductReward(uint256 workflowId, uint256 amount) external onlyExecutor
```

Deducts from the workflow's reward balance without transferring ETH.
Used for internal accounting.

**Access:** `onlyExecutor`

---

#### payExecutor

```solidity
function payExecutor(uint256 workflowId, uint256 amount, address executor) external onlyExecutor
```

Deducts from the workflow's reward balance and transfers ETH to the
executor address.

**Access:** `onlyExecutor`

**Reverts:**

| Error          | Condition                      |
|----------------|--------------------------------|
| `RefundFailed` | ETH transfer to executor fails |

---

#### getWorkflow

```solidity
function getWorkflow(uint256 workflowId) external view returns (DataTypes.Workflow memory)
```

Returns the full workflow struct for the given ID.

---

#### getSteps

```solidity
function getSteps(uint256 workflowId) external view returns (DataTypes.Step[] memory)
```

Returns all steps for the given workflow.

---

#### getStep

```solidity
function getStep(uint256 workflowId, uint256 stepIndex) external view returns (DataTypes.Step memory)
```

Returns a single step by workflow ID and index.

---

#### workflowCount

```solidity
function workflowCount() external view returns (uint256)
```

Returns the total number of workflows created (`_nextWorkflowId - 1`).

---

### Events

| Event              | Parameters                                                                   |
|--------------------|------------------------------------------------------------------------------|
| `WorkflowCreated`  | `uint256 indexed workflowId, address indexed owner, uint256 totalSteps, uint256 rewardPerStep` |
| `WorkflowPaused`   | `uint256 indexed workflowId`                                                 |
| `WorkflowResumed`  | `uint256 indexed workflowId`                                                 |
| `WorkflowCancelled`| `uint256 indexed workflowId, uint256 refundAmount`                           |
| `WorkflowCompleted`| `uint256 indexed workflowId`                                                 |
| `WorkflowFailed`   | `uint256 indexed workflowId, uint256 stepIndex`                              |

### Errors

| Error                | Condition                                  |
|----------------------|--------------------------------------------|
| `NoSteps`            | Step array is empty                        |
| `TooManySteps`       | Step array exceeds `MAX_STEPS`             |
| `InvalidReward`      | Reward below `MIN_REWARD_PER_STEP`         |
| `InsufficientDeposit`| `msg.value` does not cover total rewards   |
| `RefundFailed`       | ETH transfer failed on cancel or payout    |

---

## ExecutionEngine

`packages/contracts/src/core/ExecutionEngine.sol`

**Address:** `0xE8E045ad8332700E811f3424C0E902057BBd0dAE`
**Inherits:** `IExecutionEngine`, `AtlasAccessControl`

The execution coordinator. Reads workflow and step data from the
registry, validates preconditions, dispatches step execution via
`StepExecutors`, and handles success/failure outcomes.

### State Variables

| Name            | Type               | Visibility | Description                     |
|-----------------|--------------------|------------|---------------------------------|
| `registry`      | `WorkflowRegistry` | public     | Reference to the registry       |
| `rewardManager` | `RewardManager`    | public     | Reference to the reward manager |

### Functions

#### initialize

```solidity
function initialize(
    address owner_,
    address registry_,
    address rewardManager_
) external initializer
```

UUPS initializer. Sets owner and contract references.

**Parameters:**

| Name             | Type      | Description                    |
|------------------|-----------|--------------------------------|
| `owner_`         | `address` | Initial contract owner         |
| `registry_`      | `address` | WorkflowRegistry proxy address |
| `rewardManager_` | `address` | RewardManager proxy address    |

---

#### executeStep

```solidity
function executeStep(uint256 workflowId) external onlyExecutor
```

Executes the current step of the specified workflow. This is the
primary entry point for executors.

**Execution sequence:**

1. Read workflow from registry. Verify status is `ACTIVE`.
2. Read the current step from registry.
3. Verify delay condition is met (`StepLib.isDelayMet`).
4. Execute step via `StepExecutors.execute()`.
5. On success: advance workflow, pay executor, emit `StepExecuted`.
6. On failure: fail workflow, emit `StepFailed`.

**Parameters:**

| Name         | Type      | Description                  |
|--------------|-----------|------------------------------|
| `workflowId` | `uint256` | The workflow to execute next  |

**Access:** `onlyExecutor`

**Reverts:**

| Error              | Condition                                    |
|--------------------|----------------------------------------------|
| `WorkflowNotActive`| Workflow status is not `ACTIVE`              |
| `StepNotReady`     | Delay condition not met for the current step |

**Emits (on success):** `StepExecuted(workflowId, stepIndex, msg.sender, gasUsed)`
**Emits (on failure):** `StepFailed(workflowId, stepIndex, returnData)`

---

#### isStepReady

```solidity
function isStepReady(uint256 workflowId) external view returns (bool)
```

Returns `true` if the workflow's current step is ready to execute.
Checks:

1. Workflow status is `ACTIVE`.
2. `currentStepIndex < totalSteps`.
3. Delay condition is met.

This is a `view` function --- free for off-chain callers. Executors
call this to pre-filter workflows before simulation.

**Parameters:**

| Name         | Type      | Description           |
|--------------|-----------|-----------------------|
| `workflowId` | `uint256` | The workflow to check  |

**Returns:** `bool` --- `true` if the step can be executed now.

---

### Events

| Event           | Parameters                                                                          |
|-----------------|------------------------------------------------------------------------------------|
| `StepExecuted`  | `uint256 indexed workflowId, uint256 indexed stepIndex, address indexed executor, uint256 gasUsed` |
| `StepFailed`    | `uint256 indexed workflowId, uint256 indexed stepIndex, bytes reason`              |

### Errors

| Error              | Condition                        |
|--------------------|----------------------------------|
| `StepNotReady`     | Delay condition not met          |
| `WorkflowNotActive`| Workflow is not in ACTIVE status |

---

## RewardManager

`packages/contracts/src/core/RewardManager.sol`

**Address:** `0xe28489d7687b67EE99feBC81cd39331E29db4Ef2`
**Inherits:** `IRewardManager`, `AtlasAccessControl`

Manages per-workflow reward deposits and per-step reward claims.
Provides an alternative reward path to the direct
`WorkflowRegistry.payExecutor()` method used in the current flow.

### State Variables

| Name        | Type                                            | Visibility | Description                          |
|-------------|-------------------------------------------------|------------|--------------------------------------|
| `_balances` | `mapping(uint256 => uint256)`                   | private    | Workflow ID to deposited ETH balance |
| `_claimed`  | `mapping(uint256 => mapping(uint256 => bool))`  | private    | Tracks claimed step rewards          |

### Functions

#### initialize

```solidity
function initialize(address owner_) external initializer
```

UUPS initializer. Sets the contract owner.

---

#### deposit

```solidity
function deposit(uint256 workflowId) external payable
```

Deposits ETH for a workflow's reward pool.

**Parameters:**

| Name         | Type      | Description                    |
|--------------|-----------|--------------------------------|
| `workflowId` | `uint256` | Target workflow                |

**Reverts:**

| Error        | Condition        |
|--------------|------------------|
| `ZeroAmount` | `msg.value == 0` |

**Emits:** `RewardDeposited(workflowId, msg.value)`

---

#### claimReward

```solidity
function claimReward(uint256 workflowId, uint256 stepIndex, address executor) external onlyExecutor
```

Marks a step's reward as claimed. Does not transfer ETH in the
current implementation (reserved for future reward calculation logic).

**Access:** `onlyExecutor`

**Reverts:**

| Error                | Condition                         |
|----------------------|-----------------------------------|
| `AlreadyClaimed`     | Step reward already claimed       |
| `InsufficientBalance`| Workflow has zero balance         |

**Emits:** `RewardClaimed(workflowId, stepIndex, executor, 0)`

---

#### payReward

```solidity
function payReward(
    uint256 workflowId,
    uint256 stepIndex,
    address executor,
    uint256 amount
) external onlyExecutor
```

Claims and pays a specific ETH amount to the executor for a step.

**Access:** `onlyExecutor`

**Reverts:**

| Error                | Condition                                       |
|----------------------|-------------------------------------------------|
| `AlreadyClaimed`     | Step reward already claimed                     |
| `InsufficientBalance`| Workflow balance less than the requested amount |
| `TransferFailed`     | ETH transfer to executor fails                  |

**Emits:** `RewardClaimed(workflowId, stepIndex, executor, amount)`

---

#### refund

```solidity
function refund(uint256 workflowId) external
```

Refunds the entire remaining balance to the caller. Intended to be
called by the `WorkflowRegistry` on workflow cancellation.

**Reverts:**

| Error                | Condition              |
|----------------------|------------------------|
| `InsufficientBalance`| Balance is zero        |
| `TransferFailed`     | ETH transfer fails     |

**Emits:** `RewardRefunded(workflowId, msg.sender, balance)`

---

#### getBalance

```solidity
function getBalance(uint256 workflowId) external view returns (uint256)
```

Returns the current reward balance for a workflow.

---

### Events

| Event             | Parameters                                                                        |
|-------------------|-----------------------------------------------------------------------------------|
| `RewardDeposited` | `uint256 indexed workflowId, uint256 amount`                                      |
| `RewardClaimed`   | `uint256 indexed workflowId, uint256 indexed stepIndex, address indexed executor, uint256 amount` |
| `RewardRefunded`  | `uint256 indexed workflowId, address indexed owner, uint256 amount`               |

### Errors

| Error                | Condition                         |
|----------------------|-----------------------------------|
| `InsufficientBalance`| Zero or insufficient balance      |
| `AlreadyClaimed`     | Step reward already claimed       |
| `TransferFailed`     | ETH transfer failed               |
| `ZeroAmount`         | Deposit amount is zero            |

---

## StepExecutors

`packages/contracts/src/core/StepExecutors.sol`

Internal library used by `ExecutionEngine` to dispatch step execution
based on `StepType`.

### Functions

#### execute

```solidity
function execute(DataTypes.Step memory step)
    internal
    returns (DataTypes.StepExecutionResult memory)
```

Dispatches to the appropriate execution handler based on `stepType`.

**Behavior by type:**

| StepType           | Call                                     | Failure mode                   |
|--------------------|------------------------------------------|--------------------------------|
| `CONTRACT_CALL`    | `target.call{value}(callData)`           | External call reverts          |
| `TOKEN_TRANSFER`   | `target.call{value}("")`                 | ETH transfer fails             |
| `CONDITION_CHECK`  | `target.staticcall(conditionData)`       | Returns `false` or reverts     |
| `DELAY`            | No-op (returns success immediately)      | Never fails at execution time  |

**Returns:** `StepExecutionResult` with success flag, return data, and
gas consumed.

**Reverts:**

| Error                | Condition                  |
|----------------------|----------------------------|
| `UnsupportedStepType`| Unknown step type value    |

---

## AtlasAccessControl

`packages/contracts/src/access/AtlasAccessControl.sol`

Abstract base contract providing UUPS upgradeability and executor
whitelist management. All three core contracts inherit this.

### Inherits

- `OwnableUpgradeable` (OpenZeppelin)
- `UUPSUpgradeable` (OpenZeppelin)

### State Variables

| Name        | Type                        | Visibility | Description                    |
|-------------|-----------------------------|------------|--------------------------------|
| `executors` | `mapping(address => bool)`  | public     | Whitelisted executor addresses |

### Modifiers

#### onlyExecutor

```solidity
modifier onlyExecutor()
```

Reverts with `NotExecutor` if `executors[msg.sender]` is `false`.

### Functions

#### addExecutor

```solidity
function addExecutor(address executor) external onlyOwner
```

Adds an address to the executor whitelist.

**Access:** `onlyOwner`

**Reverts:**

| Error         | Condition                |
|---------------|--------------------------|
| `ZeroAddress` | `executor == address(0)` |

**Emits:** `ExecutorAdded(executor)`

---

#### removeExecutor

```solidity
function removeExecutor(address executor) external onlyOwner
```

Removes an address from the executor whitelist.

**Access:** `onlyOwner`

**Emits:** `ExecutorRemoved(executor)`

---

### Events

| Event             | Parameters                    |
|-------------------|-------------------------------|
| `ExecutorAdded`   | `address indexed executor`    |
| `ExecutorRemoved` | `address indexed executor`    |

### Errors

| Error         | Condition                      |
|---------------|--------------------------------|
| `NotExecutor` | Caller not in executor mapping |
| `ZeroAddress` | Zero address provided          |

---

## WorkflowLib

`packages/contracts/src/libraries/WorkflowLib.sol`

Library attached to `DataTypes.Workflow` via the `using` directive.
Provides validation and state transition helpers.

### Functions

| Function         | Visibility | Description                                         |
|------------------|------------|-----------------------------------------------------|
| `validateActive` | internal   | Reverts `WorkflowNotActive` if status != ACTIVE     |
| `validatePaused` | internal   | Reverts `WorkflowNotPaused` if status != PAUSED     |
| `validateOwner`  | internal   | Reverts `NotWorkflowOwner` if caller != owner       |
| `isCompleted`    | internal   | Returns true if `currentStepIndex >= totalSteps`    |
| `advanceStep`    | internal   | Increments step index, sets lastExecutedAt, auto-completes if final step |

### Errors

| Error                      | Condition                 |
|----------------------------|---------------------------|
| `WorkflowNotActive`        | Status is not ACTIVE      |
| `WorkflowNotPaused`        | Status is not PAUSED      |
| `NotWorkflowOwner`         | Caller is not the owner   |
| `WorkflowAlreadyCompleted` | Status is COMPLETED       |

---

## StepLib

`packages/contracts/src/libraries/StepLib.sol`

Library for step validation and delay checking.

### Functions

#### validate

```solidity
function validate(DataTypes.Step memory step) internal pure
```

Validates a step during workflow creation. For `CONTRACT_CALL` and
`TOKEN_TRANSFER` types, the target address must not be `address(0)`.

**Reverts:** `InvalidTarget` if target is zero address for call types.

---

#### isDelayMet

```solidity
function isDelayMet(DataTypes.Step memory step, uint256 lastExecutedAt) internal view returns (bool)
```

Returns `true` if the step's delay condition is satisfied.

- Non-`DELAY` types always return `true`.
- If `lastExecutedAt == 0` (first step), returns `true`.
- Otherwise, returns `block.timestamp >= lastExecutedAt + step.delay`.

---

### Errors

| Error              | Condition                        |
|--------------------|----------------------------------|
| `InvalidStep`      | Generic step validation failure  |
| `StepDelayNotMet`  | Delay period has not elapsed     |
| `InvalidTarget`    | Target is address(0)             |

---

## TimeTriggerLib

`packages/contracts/src/libraries/TimeTriggerLib.sol`

Utility library for time-based trigger calculations.

### Functions

#### isTimeMet

```solidity
function isTimeMet(uint256 lastExecution, uint256 interval) internal view returns (bool)
```

Returns `true` if enough time has elapsed since the last execution.
Returns `true` if `lastExecution == 0` (never executed).

---

#### timeUntilNext

```solidity
function timeUntilNext(uint256 lastExecution, uint256 interval) internal view returns (uint256)
```

Returns the number of seconds until the next execution is allowed.
Returns `0` if the interval has already passed or if `lastExecution == 0`.
