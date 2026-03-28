# Atlas Protocol --- Architecture

> Decentralized on-chain workflow orchestration on Base.

Atlas is a protocol that lets users define multi-step on-chain workflows
(contract calls, token transfers, conditional logic, timed delays) and
incentivizes a permissioned network of executors to carry them out.
Executors compete for per-step ETH rewards. The protocol is live on
Base Sepolia.

This document covers the system design, contract topology, execution
model, reward economics, and upgrade strategy.

---

## Table of Contents

1. [System Overview](#system-overview)
2. [Contract Architecture](#contract-architecture)
3. [Workflow Lifecycle](#workflow-lifecycle)
4. [Execution Flow](#execution-flow)
5. [Executor Network](#executor-network)
6. [Reward Economics](#reward-economics)
7. [NFT Ownership Model](#nft-ownership-model)
8. [Subgraph Indexing](#subgraph-indexing)
9. [Contract Addresses](#contract-addresses)
10. [Upgrade Strategy](#upgrade-strategy)
11. [Gas Optimization](#gas-optimization)
12. [Cross-Chain Design](#cross-chain-design)
13. [Security Model](#security-model)

---

## System Overview

```
+------------------------------------------------------------------+
|                        USER / DASHBOARD                          |
|                    (Next.js + wagmi + viem)                       |
+-------------+--------------------------------------+-------------+
              | create/pause/cancel                  | query
              v                                      v
+-------------------------+          +--------------------------+
|   WorkflowRegistry      |          |       The Graph          |
|   (UUPS Proxy)          |<-------->|       Subgraph           |
|                         | events   |                          |
|  - createWorkflow()     |          |  Workflow, StepExecution  |
|  - pauseWorkflow()      |          |  Executor, ProtocolStat  |
|  - cancelWorkflow()     |          +--------------------------+
|  - payExecutor()        |
+-------------+-----------+
              | reads/writes
              v
+-------------------------+     +------------------------------+
|   ExecutionEngine       |     |   WorkflowNFT (ERC721)       |
|   (UUPS Proxy)          |     |   (UUPS Proxy)               |
|                         |     |                              |
|  - executeStep()        |     |  - createWorkflow() -> mint  |
|  - isStepReady()        |     |  - transfer -> owner sync    |
|                         |     |  - tokenURI() on-chain       |
+-------------+-----------+     +------------------------------+
              | monitors
              v
+------------------------------------------------------------------+
|                       EXECUTOR NETWORK                           |
|                                                                  |
|   +---------+  +---------+  +---------+                          |
|   |Executor1|  |Executor2|  |Executor3|  ... (TypeScript+viem)   |
|   +----+----+  +----+----+  +----+----+                          |
|        |            |            |                                |
|   BlockMonitor -> WorkflowScanner -> TriggerEvaluator            |
|        -> Simulator -> GasEstimator -> Submitter                 |
+------------------------------------------------------------------+
```

**Package map:**

| Package               | Purpose                                    |
|------------------------|--------------------------------------------|
| `packages/contracts`   | Solidity contracts (Foundry)               |
| `packages/executor`    | Off-chain executor node (TypeScript, viem) |
| `packages/dashboard`   | User-facing UI (Next.js, wagmi)            |
| `packages/subgraph`    | The Graph subgraph (AssemblyScript)        |
| `packages/sdk`         | Client SDK for programmatic access         |
| `packages/shared`      | Constants, ABIs, types shared across packages |

---

## Contract Architecture

Four contracts deployed behind UUPS proxies, plus one library contract
deployed inline.

```
+------------------+       +------------------+       +------------------+
| AtlasAccessControl|      | AtlasAccessControl|      | AtlasAccessControl|
| (OwnableUpgradeable     | (OwnableUpgradeable     | (OwnableUpgradeable
|  + UUPSUpgradeable)     |  + UUPSUpgradeable)     |  + UUPSUpgradeable)
+--------+---------+       +--------+---------+       +--------+---------+
         |                          |                          |
+--------v---------+       +--------v---------+       +--------v---------+
| WorkflowRegistry |       | ExecutionEngine  |       |  RewardManager   |
|                  |       |                  |       |                  |
| Stores workflows |<------| Executes steps   |       | Deposits/claims  |
| and steps.       |       | via StepExecutors|       | reward balances  |
| Holds reward ETH.|       | library.         |       |                  |
+------------------+       +------------------+       +------------------+
                                    |
                           +--------v---------+
                           |  StepExecutors   |
                           |  (library)       |
                           |                  |
                           | CONTRACT_CALL    |
                           | TOKEN_TRANSFER   |
                           | CONDITION_CHECK  |
                           | DELAY            |
                           +------------------+
```

**Access control model:**

- `owner` --- Single admin address. Can upgrade contracts and manage
  the executor whitelist.
- `executors` --- Whitelisted addresses. Can call `executeStep`,
  `advanceWorkflow`, `failWorkflow`, `payExecutor`, `deductReward`,
  `claimReward`, and `payReward`.
- `workflow.owner` --- The address that created a workflow. Can pause,
  resume, and cancel that specific workflow.

```
                    owner
                      |
          +-----------+-----------+
          |                       |
    addExecutor()           removeExecutor()
          |                       |
          v                       v
   executors[addr] = true   executors[addr] = false
          |
          v
   onlyExecutor modifier gates:
     - ExecutionEngine.executeStep()
     - WorkflowRegistry.advanceWorkflow()
     - WorkflowRegistry.failWorkflow()
     - WorkflowRegistry.payExecutor()
     - WorkflowRegistry.deductReward()
     - RewardManager.claimReward()
     - RewardManager.payReward()
```

**Supporting libraries:**

| Library          | Responsibility                                      |
|------------------|-----------------------------------------------------|
| `WorkflowLib`    | State validation (active, paused, owner), step advancement |
| `StepLib`        | Step validation (non-zero target), delay checking   |
| `TimeTriggerLib` | Time-interval trigger math                          |
| `StepExecutors`  | Dispatch and execute steps by type                  |

---

## Workflow Lifecycle

A workflow is an ordered sequence of steps. Each step has a type, a
target address, calldata, a value, and an optional delay.

**State machine:**

```
                    +----------+
           create   |          |
     -------------->|  ACTIVE  |<--- resume
                    |          |
                    +--+---+---+
                       |   |
              pause ---+   +--- executeStep (final step)
                       |               |
                    +--v---+    +------v------+
                    |PAUSED|    |  COMPLETED  |
                    +--+---+    +-------------+
                       |
              cancel --+
                       |
                    +--v---+
                    |FAILED|<-- step execution fails
                    +------+
```

**Status enum:**

| Value | Name        | Meaning                                       |
|-------|-------------|-----------------------------------------------|
| 0     | `NONE`      | Workflow ID does not exist                     |
| 1     | `ACTIVE`    | Accepting step executions                      |
| 2     | `PAUSED`    | Owner paused; no executions until resumed      |
| 3     | `COMPLETED` | All steps executed successfully                |
| 4     | `FAILED`    | Step failed or owner cancelled                 |

**Transitions:**

| From       | To          | Trigger                            | Who              |
|------------|-------------|------------------------------------|------------------|
| (none)     | `ACTIVE`    | `createWorkflow()`                 | Any user         |
| `ACTIVE`   | `PAUSED`    | `pauseWorkflow(workflowId)`        | Workflow owner   |
| `PAUSED`   | `ACTIVE`    | `resumeWorkflow(workflowId)`       | Workflow owner   |
| `ACTIVE`   | `COMPLETED` | `advanceStep()` on final step      | ExecutionEngine  |
| `ACTIVE`   | `FAILED`    | Step execution returns failure     | ExecutionEngine  |
| `ACTIVE`   | `FAILED`    | `cancelWorkflow(workflowId)`       | Workflow owner   |
| `PAUSED`   | `FAILED`    | `cancelWorkflow(workflowId)`       | Workflow owner   |

**Invariants:**

- A completed workflow cannot be cancelled, paused, or resumed.
- A failed workflow cannot be resumed.
- Only the workflow owner can pause, resume, or cancel.
- `currentStepIndex` only increments; it never decrements.

---

## Execution Flow

The full path from executor to on-chain state change:

```
Executor                    ExecutionEngine              WorkflowRegistry
   |                              |                           |
   |  executeStep(workflowId)     |                           |
   |----------------------------->|                           |
   |                              |  getWorkflow(id)          |
   |                              |-------------------------->|
   |                              |  <-- workflow data -------|
   |                              |  getStep(id, index)       |
   |                              |-------------------------->|
   |                              |  <-- step data -----------|
   |                              |                           |
   |                              |  [validate: status=ACTIVE,|
   |                              |   delay met, conditions]  |
   |                              |                           |
   |                              |  StepExecutors.execute()  |
   |                              |  (CONTRACT_CALL/DELAY/...)|
   |                              |                           |
   |                              |  advanceWorkflow(id)      |
   |                              |-------------------------->|
   |                              |  payExecutor(id,amt,addr) |
   |                              |-------------------------->|
   |  <-- reward ETH ------------|                           |
   |                              |  emit StepExecuted        |
   |                              |                           |
```

**Step types and their execution behavior:**

| StepType           | What happens on-chain                                     |
|--------------------|-----------------------------------------------------------|
| `CONTRACT_CALL`    | `target.call{value}(callData)` --- arbitrary external call |
| `TOKEN_TRANSFER`   | `target.call{value}("")` --- native ETH transfer          |
| `CONDITION_CHECK`  | `target.staticcall(conditionData)` --- must return `true`  |
| `DELAY`            | No-op. Validated before execution via `StepLib.isDelayMet` |

**Failure path:**

If `StepExecutors.execute()` returns `success = false`, the
ExecutionEngine calls `registry.failWorkflow(workflowId, stepIndex)`
and emits `StepFailed`. The workflow transitions to `FAILED`. The
executor does not receive a reward for a failed step.

---

## Executor Network

Executors are off-chain TypeScript processes that monitor the chain,
identify ready workflows, and submit `executeStep` transactions.

**Pipeline:**

```
+---------------+     +------------------+     +-------------------+
| BlockMonitor  |---->| WorkflowScanner  |---->| TriggerEvaluator  |
| (watchBlocks) |     | (scan all IDs,   |     | (hash-based       |
|               |     |  call isStepReady|     |  priority filter)  |
+---------------+     +------------------+     +-------------------+
                                                        |
                                                        v
+---------------+     +------------------+     +-------------------+
|   Submitter   |<----| GasEstimator     |<----| Simulator         |
| (sendTx,      |     | (EIP-1559 fees,  |     | (estimateGas to   |
|  wait receipt) |     |  profitability)  |     |  verify success)  |
+---------------+     +------------------+     +-------------------+
```

**Component responsibilities:**

| Component          | File                               | Purpose                                              |
|--------------------|------------------------------------|------------------------------------------------------|
| `BlockMonitor`     | `monitor/block-monitor.ts`         | Subscribes to new blocks via `watchBlockNumber`      |
| `WorkflowScanner`  | `monitor/workflow-scanner.ts`      | Iterates all workflow IDs, calls `isStepReady`       |
| `TriggerEvaluator` | `scheduler/trigger-evaluator.ts`   | Deterministic hash to assign workflow-step priority   |
| `Simulator`        | `execution/simulator.ts`           | Calls `estimateGas` against `executeStep` calldata   |
| `GasEstimator`     | `gas/gas-estimator.ts`             | EIP-1559 fee calculation, profitability check        |
| `Submitter`        | `execution/submitter.ts`           | Signs and sends transaction, waits for confirmation  |
| `RetryManager`     | `execution/retry-manager.ts`       | Exponential backoff retry (max 3 attempts)           |
| `NonceManager`     | `nonce/nonce-manager.ts`           | Local nonce tracking to avoid RPC round-trips        |
| `PriorityQueue`    | `scheduler/priority-queue.ts`      | Generic sorted queue for execution ordering          |
| `Metrics`          | `telemetry/metrics.ts`             | In-memory counters and gauges                        |

**Executor selection --- deterministic hash:**

```
hash(workflowId, stepIndex, blockNumber) % executorCount = priority

Block N:     Executor 2 has priority -> executes
Block N+1:   Executor 2 didn't act  -> Executor 0 takes over
Block N+2:   Fallback -> any executor can execute
```

The `TriggerEvaluator` computes:

```
keccak256(abi.encodePacked(workflowId, stepIndex, blockNumber)) % totalExecutors
```

If the result matches `executorIndex`, the workflow is "claimed" by
this executor for the current block. This distributes work
deterministically without on-chain coordination.

**Scan cadence:**

- Block callback fires on every new block (~2s on Base).
- Full workflow scan runs every 6th block (~12s) and on a configurable
  interval (`SCAN_INTERVAL_MS`, default 12000ms).
- The `processing` lock prevents overlapping scans.

---

## Reward Economics

Workflow creators deposit ETH when creating a workflow. The deposit
must cover `rewardPerStep * totalSteps`. Executors earn `rewardPerStep`
for each successfully executed step.

**Current model --- flat per-step reward:**

```
Deposit flow:

  User ---(msg.value)---> WorkflowRegistry.createWorkflow()
                          stores in wf.rewardBalance

Payout flow:

  ExecutionEngine.executeStep()
    |
    +-> registry.payExecutor(workflowId, rewardPerStep, executor)
         |
         +-> wf.rewardBalance -= rewardPerStep
         +-> executor.call{value: rewardPerStep}("")
```

**Cancellation refund:**

When an owner cancels, the remaining `rewardBalance` is refunded to
the owner. Steps already executed and paid are not clawed back.

**Dutch auction model (planned):**

```
Price
  |
  | rewardPerStep ----+
  |                    \
  |                     \  Linear decrease
  |                      \
  |                       \
  | floorPrice -------------\--------------------
  |                         |
  |-------------------------+-------------------- Blocks
  |  startBlock          endBlock
  |
  |  <-- Auction Window --> <-- Fallback ------->
  |  (competitive bidding)   (anyone at floor)
```

In the auction model, the reward starts at `rewardPerStep` and decays
linearly to `floorPrice` over a configurable block window. Early
execution is more profitable, creating competition. After the window
closes, any executor can execute at floor price.

**RewardManager contract:**

The `RewardManager` provides an alternative deposit/claim path with
per-step claim tracking via `_claimed[workflowId][stepIndex]`. In the
current flow, the `WorkflowRegistry` holds ETH directly and the
`ExecutionEngine` calls `registry.payExecutor()`. The `RewardManager`
exists for future reward models.

| Flow               | ETH held by          | Payout via                        |
|--------------------|----------------------|-----------------------------------|
| Current (MVP)      | `WorkflowRegistry`   | `registry.payExecutor()`          |
| Future (auction)   | `RewardManager`      | `rewardManager.payReward()`       |

---

## NFT Ownership Model

Planned but not yet deployed. The `WorkflowNFT` contract would mint an
ERC-721 token for each workflow, enabling transferable ownership.

```
User                WorkflowNFT            WorkflowRegistry
 |                       |                       |
 | createWorkflow()      |                       |
 |---------------------->|                       |
 |                       | createWorkflowFor()   |
 |                       |---------------------->|
 |                       | <-- workflowId -------|
 |                       |                       |
 |                       | _mint(user, id)       |
 | <-- NFT minted -------|                       |
 |                       |                       |
 | transfer NFT to Bob   |                       |
 |---------------------->|                       |
 |                       | setWorkflowOwner()    |
 |                       |---------------------->|
 |                       |  owner = Bob          |
```

When implemented, NFT transfers will trigger an `_afterTokenTransfer`
hook that calls `registry.setWorkflowOwner()`, keeping on-chain
ownership in sync.

---

## Subgraph Indexing

The Graph subgraph indexes events from all three deployed contracts.

**Data sources:**

| Contract           | Events indexed                                            |
|--------------------|-----------------------------------------------------------|
| WorkflowRegistry   | WorkflowCreated, WorkflowPaused, WorkflowResumed, WorkflowCancelled, WorkflowCompleted, WorkflowFailed |
| ExecutionEngine    | StepExecuted, StepFailed                                  |
| RewardManager      | RewardClaimed                                             |

**Entities:**

| Entity            | Key fields                                                 |
|-------------------|------------------------------------------------------------|
| `Workflow`        | id, owner, status, totalSteps, rewardPerStep, createdAt    |
| `StepExecution`   | workflowId, stepIndex, executor, gasUsed, timestamp        |
| `Executor`        | address, totalExecutions, totalRewards                     |
| `ProtocolStat`    | totalWorkflows, activeWorkflows, totalStepsExecuted        |

**Start block:** 38986980 (Base Sepolia deployment block).

The dashboard queries the subgraph for workflow lists, execution
history, and executor leaderboards rather than making direct RPC calls
for historical data.

---

## Contract Addresses

**Network: Base Sepolia (chain ID 84532)**

| Contract           | Address                                      |
|--------------------|----------------------------------------------|
| WorkflowRegistry   | `0xc17F81db41a12a396e54DA9694B323148c945117`  |
| ExecutionEngine    | `0xE8E045ad8332700E811f3424C0E902057BBd0dAE`  |
| RewardManager      | `0xe28489d7687b67EE99feBC81cd39331E29db4Ef2`  |

All contracts are deployed behind ERC-1967 transparent proxies using
the UUPS upgrade pattern. The implementation addresses are not listed
here because they change on upgrade; query the proxy's
`implementation()` slot for the current implementation.

---

## Upgrade Strategy

All three contracts inherit `AtlasAccessControl`, which extends
`OwnableUpgradeable` and `UUPSUpgradeable`.

**UUPS pattern:**

- The proxy delegates all calls to an implementation contract.
- The `_authorizeUpgrade` function is protected by `onlyOwner`.
- Upgrades are initiated by calling `upgradeTo(newImpl)` or
  `upgradeToAndCall(newImpl, data)` on the proxy.

**Storage layout rules:**

1. Never reorder existing storage variables.
2. Never remove existing storage variables.
3. Append new variables at the end of the contract's storage layout.
4. Use storage gaps (`uint256[50] __gap`) in base contracts if
   extending the inheritance chain.

**Current storage layout:**

```
WorkflowRegistry:
  slot 0   _nextWorkflowId          uint256
  slot 1   _workflows               mapping(uint256 => Workflow)
  slot 2   _steps                   mapping(uint256 => Step[])
  (inherited) executors              mapping(address => bool)

ExecutionEngine:
  slot 0   registry                 WorkflowRegistry (address)
  slot 1   rewardManager            RewardManager (address)
  (inherited) executors              mapping(address => bool)

RewardManager:
  slot 0   _balances                mapping(uint256 => uint256)
  slot 1   _claimed                 mapping(uint256 => mapping(uint256 => bool))
  (inherited) executors              mapping(address => bool)
```

**Upgrade checklist:**

1. Write the new implementation contract.
2. Run `forge test` with the full test suite (unit, fuzz, integration).
3. Deploy the new implementation to the target network.
4. Call `upgradeTo(newImplAddress)` from the owner account.
5. Verify the new implementation on the block explorer.

---

## Gas Optimization

**Struct packing:**

The `DataTypes.Workflow` struct stores 9 fields across multiple storage
slots. A future `WorkflowV2` design packs status, currentStepIndex,
and totalSteps into a single `uint256` using bit-shifting:

```
Proposed WorkflowV2 packing (single slot):

  [255..200] unused
  [199..136] lastExecutedAt  (uint64, sufficient until year 2554)
  [135..72]  createdAt       (uint64)
  [71..40]   rewardPerStep   (uint32, in units of 0.0001 ETH)
  [39..24]   totalSteps      (uint16, max 65535)
  [23..8]    currentStepIndex(uint16)
  [7..0]     status          (uint8)
```

**Minimized storage reads:**

- `ExecutionEngine.executeStep()` reads workflow and step data from
  the registry via external view calls rather than duplicating storage.
- `isStepReady()` is a `view` function, costing no gas for off-chain
  callers (used by executors to pre-filter).

**Calldata over memory:**

- `createWorkflow` accepts `Step[] calldata` rather than `memory`,
  saving the memory copy cost for large step arrays.

**Constants:**

- `MAX_STEPS = 50` and `MIN_REWARD_PER_STEP = 0.0001 ether` are
  `constant`, stored in bytecode, not in storage.

---

## Cross-Chain Design

Atlas is currently single-chain (Base Sepolia). The architecture
supports future cross-chain workflows through these patterns:

**DAG-based workflows:**

The current model is a linear step sequence. A DAG extension would
allow branching and parallel execution paths:

```
Current (linear):    Step 0 -> Step 1 -> Step 2 -> Step 3

Future (DAG):        Step 0 --+--> Step 1a --+--> Step 3
                              |              |
                              +--> Step 1b --+
```

Each step would declare dependencies (parent step indices that must
complete before it can execute). The `advanceStep` logic would check
all parents rather than a single `currentStepIndex`.

**Bridge oracle pattern:**

For cross-chain steps (e.g., execute a contract call on Arbitrum as
part of a workflow on Base):

```
Base                    Bridge Oracle              Arbitrum
 |                           |                        |
 | Step N: bridgeRequest()   |                        |
 |-------------------------->|                        |
 |                           | relayExecution()       |
 |                           |----------------------->|
 |                           | <-- result ------------|
 | <-- confirmBridge() ------|                        |
 | Step N+1 unlocked         |                        |
```

A trusted or decentralized bridge oracle monitors the source chain for
bridge requests, executes the operation on the destination chain, and
posts a confirmation back. This is not yet implemented.

---

## Security Model

**Executor whitelist:**

Only addresses in the `executors` mapping can call state-mutating
functions on the `ExecutionEngine` and `WorkflowRegistry`. The contract
owner manages this list. This prevents unauthorized step execution and
reward claims.

**Executor staking (planned):**

Future versions will require executors to stake ETH or a protocol token
as collateral. Staked executors gain access to the execution pool.
Stake serves two purposes:

1. **Sybil resistance** --- prevents one entity from registering many
   executor addresses to capture disproportionate rewards.
2. **Slashing collateral** --- misbehaving executors lose stake.

**Slashing conditions (planned):**

| Condition                  | Penalty                                    |
|----------------------------|--------------------------------------------|
| Submitting a failing step  | Executor pays gas but receives no reward   |
| Intentional griefing       | Stake slashed, executor removed            |
| Prolonged inactivity       | Reduced priority score                     |

**Reputation system (planned):**

Executors accumulate a reputation score based on:

- Successful executions (positive)
- Failed executions (negative)
- Uptime and responsiveness (positive)
- Gas efficiency (positive)

Higher reputation increases priority in the executor selection hash,
giving reliable executors first access to profitable workflows.

**Auction manipulation resistance:**

In the dutch auction model, resistance to manipulation comes from:

1. **Deterministic priority** --- the hash-based selection prevents
   front-running by assigning priority before the block is mined.
2. **Floor price** --- the auction has a minimum price, preventing
   race-to-zero attacks.
3. **Time decay** --- waiting too long to capture a lower price risks
   another executor claiming the step.
4. **Simulation requirement** --- executors simulate before submitting,
   filtering out transactions that would fail.

**Current protections (deployed):**

| Protection                        | Mechanism                              |
|-----------------------------------|----------------------------------------|
| Unauthorized execution            | `onlyExecutor` modifier                |
| Unauthorized workflow mutation     | `validateOwner` check                  |
| Double execution                  | `currentStepIndex` only increments     |
| Insufficient deposit              | `msg.value >= rewardPerStep * steps`   |
| Zero-address executor             | `ZeroAddress` error in `addExecutor`   |
| Reentrancy on payouts             | State updated before external call     |
| Upgrade hijacking                 | `onlyOwner` on `_authorizeUpgrade`     |
