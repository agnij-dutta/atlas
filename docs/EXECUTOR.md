# Atlas Protocol --- Executor Node

> Architecture, configuration, and operation guide for running an
> Atlas executor.

An executor is an off-chain TypeScript process that monitors the Base
chain for ready workflows, simulates step execution, estimates gas
costs, and submits profitable transactions. Executors earn ETH rewards
for each successfully executed step.

---

## Table of Contents

1. [Architecture](#architecture)
2. [Pipeline](#pipeline)
3. [Components](#components)
4. [Configuration](#configuration)
5. [Running an Executor](#running-an-executor)
6. [Executor Selection](#executor-selection)
7. [Profitability Engine](#profitability-engine)
8. [Nonce Management](#nonce-management)
9. [Retry Strategy](#retry-strategy)
10. [Telemetry](#telemetry)
11. [Troubleshooting](#troubleshooting)

---

## Architecture

The executor is a single long-running process in `packages/executor/`.
It uses `viem` for chain interaction and `pino` for structured logging.

**Source layout:**

```
packages/executor/src/
  index.ts                       Entry point and main loop
  config/
    index.ts                     Configuration loader (env vars)
  chain/
    provider.ts                  viem PublicClient + WalletClient setup
    contracts.ts                 Contract bindings (minimal ABIs)
  monitor/
    block-monitor.ts             Block subscription via watchBlockNumber
    workflow-scanner.ts          Iterates workflows, checks readiness
  scheduler/
    trigger-evaluator.ts         Deterministic hash priority assignment
    priority-queue.ts            Generic sorted queue
  execution/
    simulator.ts                 Pre-execution simulation (estimateGas)
    submitter.ts                 Transaction signing and submission
    retry-manager.ts             Exponential backoff retry logic
  gas/
    gas-estimator.ts             EIP-1559 fee estimation + profitability
  nonce/
    nonce-manager.ts             Local nonce tracking
  telemetry/
    logger.ts                    pino logger with pino-pretty transport
    metrics.ts                   In-memory counters and gauges
```

---

## Pipeline

Every scan cycle executes this pipeline:

```
+---------------+     +------------------+     +-------------------+
| BlockMonitor  |---->| WorkflowScanner  |---->| TriggerEvaluator  |
| Subscribe to  |     | For each ID 1..N |     | keccak256 hash    |
| new blocks    |     | call isStepReady |     | modulo selection  |
+---------------+     +------------------+     +-------------------+
                                                        |
                                                        v
+---------------+     +------------------+     +-------------------+
|   Submitter   |<----| GasEstimator     |<----| Simulator         |
| sendTransaction     | EIP-1559 fees    |     | estimateGas       |
| waitForReceipt|     | profitability    |     | dry-run the call  |
+---------------+     +------------------+     +-------------------+
```

**Step-by-step:**

1. **BlockMonitor** receives a new block number.
2. On every 6th block (~12 seconds), a scan triggers.
3. **WorkflowScanner** iterates workflow IDs 1 through `workflowCount()`.
   For each, it calls `isStepReady()` on the ExecutionEngine. Workflows
   where the current step is ready are collected.
4. **TriggerEvaluator** filters the ready list. For each workflow, it
   computes `keccak256(workflowId, stepIndex, blockNumber) % totalExecutors`.
   If the result matches this executor's index, the workflow is claimed.
5. **Simulator** calls `estimateGas` against the `executeStep` calldata.
   If the simulation reverts, the workflow is skipped (the step would
   fail on-chain).
6. **GasEstimator** reads the latest block's base fee, computes
   EIP-1559 gas parameters, and checks whether the reward exceeds the
   gas cost times the profitability multiplier.
7. **Submitter** signs and sends the transaction using the managed
   nonce. It waits for one confirmation and records success or failure
   in metrics.

A `processing` lock prevents overlapping scan cycles.

---

## Components

### BlockMonitor

**File:** `monitor/block-monitor.ts`

Subscribes to new blocks using `viem`'s `watchBlockNumber`. Stores the
latest block number and invokes a callback on each new block.

| Method            | Description                                        |
|-------------------|----------------------------------------------------|
| `start(onBlock)`  | Begins watching. Calls `onBlock(blockNumber)`.     |
| `stop()`          | Unsubscribes from block events.                    |
| `getLatestBlock()`| Returns the most recently seen block number.       |

---

### WorkflowScanner

**File:** `monitor/workflow-scanner.ts`

Scans all workflow IDs by calling `workflowCount()` on the registry
and then checking `isStepReady()` on the engine for each ID.

| Method                  | Returns                   | Description                        |
|-------------------------|---------------------------|------------------------------------|
| `scanActiveWorkflows()` | `WorkflowScanResult[]`    | Array of ready workflows           |

**WorkflowScanResult:**

```typescript
{
  workflowId: bigint;
  currentStepIndex: bigint;
  rewardPerStep: bigint;
}
```

Errors from individual workflow checks are suppressed (the workflow may
have been cancelled between the count read and the readiness check).
Unexpected errors are logged at `warn` level.

---

### TriggerEvaluator

**File:** `scheduler/trigger-evaluator.ts`

Deterministically assigns workflow execution priority across the
executor network.

| Method                                        | Returns                | Description                           |
|-----------------------------------------------|------------------------|---------------------------------------|
| `filterByPriority(workflows, blockNumber)`    | `WorkflowScanResult[]` | Workflows assigned to this executor   |

**Priority calculation:**

```typescript
keccak256(encodePacked(workflowId, stepIndex, blockNumber)) % totalExecutors
```

If the result equals `executorIndex`, this executor has priority. With
`totalExecutors = 1`, the single executor always has priority.

---

### Simulator

**File:** `execution/simulator.ts`

Performs a dry-run of `executeStep` by calling `estimateGas`. If the
call would revert on-chain, `estimateGas` throws, and the simulator
returns `{ success: false, gasEstimate: 0n }`.

| Method                            | Returns                                     |
|-----------------------------------|---------------------------------------------|
| `simulate(workflowId, account)`   | `{ success: boolean, gasEstimate: bigint }` |

The `executeStep` calldata is manually encoded: function selector
`0x1c5f1452` concatenated with the ABI-encoded `uint256 workflowId`.

---

### GasEstimator

**File:** `gas/gas-estimator.ts`

Computes EIP-1559 gas parameters and determines whether execution is
profitable.

| Method                                      | Returns          | Description                          |
|---------------------------------------------|------------------|--------------------------------------|
| `estimate(gasLimit)`                        | `GasEstimate`    | Fee parameters and estimated cost    |
| `isProfitable(reward, gasCost, multiplier)` | `boolean`        | True if reward >= gasCost * multiplier |

**GasEstimate:**

```typescript
{
  maxFeePerGas: bigint;          // baseFee * 2 + priorityFee
  maxPriorityFeePerGas: bigint;  // Fixed at 1.5 gwei
  estimatedCost: bigint;         // gasLimit * maxFeePerGas
}
```

The `maxFeePerGas` is clamped to the configured `maxGasPrice` ceiling.

**Profitability check:**

```
profitable = reward >= gasCost * profitabilityMultiplier
```

With the default multiplier of 1.2, the reward must be at least 20%
higher than the estimated gas cost.

---

### Submitter

**File:** `execution/submitter.ts`

Signs and sends the `executeStep` transaction.

| Method                              | Returns         | Description                              |
|-------------------------------------|-----------------|------------------------------------------|
| `submitExecution(workflowId, gas)`  | `Hash \| null`  | Transaction hash, or null on failure     |
| `waitForConfirmation(hash)`         | `boolean`       | True if receipt status is `success`      |

On submission failure, the `NonceManager` is reset to re-sync with
the chain.

---

### RetryManager

**File:** `execution/retry-manager.ts`

Provides exponential backoff retry with a maximum of 3 attempts.

| Method                | Description                                         |
|-----------------------|-----------------------------------------------------|
| `shouldRetry(key)`    | Returns true if attempts < 3                        |
| `retry(key, fn)`      | Executes `fn` with backoff delay (1s, 2s, 4s)      |
| `clear(key)`          | Resets retry count for a key (on success)           |

Retry keys are formatted as `{workflowId}-{stepIndex}`.

---

### NonceManager

**File:** `nonce/nonce-manager.ts`

Tracks the transaction nonce locally to avoid an RPC round-trip on
every submission.

| Method           | Description                                            |
|------------------|--------------------------------------------------------|
| `getNextNonce()` | Returns the next nonce (fetches from chain on first call, increments locally after) |
| `reset()`        | Clears the cached nonce, forcing a fresh fetch         |

The nonce is reset whenever a submission fails, ensuring the local
counter stays in sync with the chain.

---

### PriorityQueue

**File:** `scheduler/priority-queue.ts`

Generic sorted queue used for execution ordering. Items are sorted by
descending priority (highest priority dequeued first).

| Method                   | Description                          |
|--------------------------|--------------------------------------|
| `enqueue(data, priority)`| Adds item and re-sorts               |
| `dequeue()`              | Removes and returns highest priority |
| `peek()`                 | Returns highest priority without removing |
| `size`                   | Number of items in the queue         |
| `clear()`                | Empties the queue                    |

---

## Configuration

All configuration is loaded from environment variables. See
`.env.example` at the repository root.

### Required Variables

| Variable           | Type     | Description                                  |
|--------------------|----------|----------------------------------------------|
| `PRIVATE_KEY`      | `string` | `0x`-prefixed 64-character hex private key. The corresponding address must be whitelisted as an executor on-chain. |
| `REGISTRY_ADDRESS` | `string` | WorkflowRegistry proxy address               |
| `ENGINE_ADDRESS`   | `string` | ExecutionEngine proxy address                |
| `REWARD_ADDRESS`   | `string` | RewardManager proxy address                  |

### Optional Variables

| Variable                 | Type     | Default                    | Description                            |
|--------------------------|----------|----------------------------|----------------------------------------|
| `RPC_URL`                | `string` | `https://sepolia.base.org` | JSON-RPC endpoint                      |
| `EXECUTOR_INDEX`         | `number` | `0`                        | This executor's index in the network   |
| `TOTAL_EXECUTORS`        | `number` | `1`                        | Total number of executors in the network |
| `BLOCK_INTERVAL_MS`      | `number` | `2000`                     | Block polling interval (ms)            |
| `SCAN_INTERVAL_MS`       | `number` | `12000`                    | Full workflow scan interval (ms)       |
| `PROFITABILITY_MULTIPLIER` | `number` | `1.2`                    | Minimum reward/cost ratio              |
| `MAX_GAS_PRICE`          | `string` | `50000000000`              | Maximum gas price in wei (50 gwei)     |
| `LOG_LEVEL`              | `string` | `info`                     | pino log level (trace/debug/info/warn/error/fatal) |

### Example .env

```bash
# Executor identity
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Contract addresses (Base Sepolia)
REGISTRY_ADDRESS=0xc17F81db41a12a396e54DA9694B323148c945117
ENGINE_ADDRESS=0xE8E045ad8332700E811f3424C0E902057BBd0dAE
REWARD_ADDRESS=0xe28489d7687b67EE99feBC81cd39331E29db4Ef2

# Network
RPC_URL=https://sepolia.base.org

# Executor network position
EXECUTOR_INDEX=0
TOTAL_EXECUTORS=3

# Gas settings
PROFITABILITY_MULTIPLIER=1.2
MAX_GAS_PRICE=50000000000

# Logging
LOG_LEVEL=info
```

---

## Running an Executor

### Prerequisites

- Node.js 18+
- A funded wallet on Base Sepolia (for gas)
- The wallet address whitelisted as an executor on-chain by the
  protocol owner via `addExecutor()`

### Setup

```bash
# Clone and install
git clone https://github.com/your-org/atlas.git
cd atlas
npm install

# Configure
cp .env.example .env
# Edit .env with your private key and contract addresses

# Build
cd packages/executor
npm run build

# Run
npm run start
```

### Verifying executor status

Before running, confirm your address is whitelisted:

```typescript
// Using viem or cast
cast call $REGISTRY_ADDRESS "executors(address)(bool)" $YOUR_ADDRESS --rpc-url $RPC_URL
// Should return: true
```

If the call returns `false`, contact the protocol owner to run:

```bash
cast send $REGISTRY_ADDRESS "addExecutor(address)" $YOUR_ADDRESS \
  --private-key $OWNER_PRIVATE_KEY --rpc-url $RPC_URL
```

### Expected log output

```
[12:00:00] INFO: Starting Atlas Executor
[12:00:01] INFO: Starting block monitor { block: 39000100 }
[12:00:01] INFO: Executor running { address: "0x...", executorIndex: 0 }
[12:00:12] INFO: Scan complete { readyCount: 2 }
[12:00:12] DEBUG: Claimed workflow { workflowId: "5" }
[12:00:12] DEBUG: Simulation passed { workflowId: "5", gasEstimate: "85000" }
[12:00:12] DEBUG: Gas estimate { baseFee: "50000000", maxFeePerGas: "1600000000", ... }
[12:00:13] INFO: Transaction submitted { workflowId: "5", hash: "0xabc..." }
[12:00:15] INFO: Transaction confirmed { hash: "0xabc...", status: "success", gasUsed: "78000" }
```

### Graceful shutdown

Send `SIGINT` (Ctrl+C). The executor stops the block monitor, logs
final metrics, and exits.

```
[12:05:00] INFO: Shutting down...
[12:05:00] INFO: Final metrics {
  "counter.successful_executions": 12,
  "counter.failed_executions": 1,
  "counter.simulation_failures": 3,
  "counter.unprofitable_skips": 7
}
```

---

## Executor Selection

Atlas uses deterministic hashing to distribute work across executors
without on-chain coordination.

**Algorithm:**

```
priority = keccak256(abi.encodePacked(workflowId, stepIndex, blockNumber))
             % totalExecutors

if priority == executorIndex:
    this executor has priority for this workflow at this block
```

**Properties:**

- **Deterministic:** All executors compute the same result for the
  same inputs. No communication needed.
- **Fair:** Over many blocks, each executor gets roughly equal work.
- **Block-rotating:** Priority changes every block. If the assigned
  executor does not act, a different executor gets priority next block.
- **No single point of failure:** If an executor goes offline, its
  assigned workflows rotate to others within one block.

**Single executor mode:**

With `TOTAL_EXECUTORS=1` and `EXECUTOR_INDEX=0`, the modulo always
returns 0, so the single executor claims every workflow. This is the
default configuration.

**Multi-executor deployment:**

For N executors, assign each a unique `EXECUTOR_INDEX` from 0 to N-1
and set `TOTAL_EXECUTORS=N` on all nodes.

```
Executor 0: EXECUTOR_INDEX=0, TOTAL_EXECUTORS=3
Executor 1: EXECUTOR_INDEX=1, TOTAL_EXECUTORS=3
Executor 2: EXECUTOR_INDEX=2, TOTAL_EXECUTORS=3
```

---

## Profitability Engine

Executors only submit transactions that are expected to be profitable.

**Decision flow:**

```
reward (rewardPerStep from workflow)
  |
  v
gasCost = gasEstimate * maxFeePerGas
  |
  v
profitable = reward >= gasCost * PROFITABILITY_MULTIPLIER
  |
  +-- yes --> submit transaction
  +-- no  --> skip, log "unprofitable_skips"
```

**Gas fee calculation (EIP-1559):**

```
maxPriorityFeePerGas = 1.5 gwei (hardcoded)
maxFeePerGas         = min(baseFee * 2 + maxPriorityFeePerGas, MAX_GAS_PRICE)
estimatedCost        = gasLimit * maxFeePerGas
```

**Tuning:**

- Lower `PROFITABILITY_MULTIPLIER` (e.g., 1.05) to execute more
  workflows at thinner margins.
- Raise `MAX_GAS_PRICE` to continue operating during gas spikes.
- Lower `MAX_GAS_PRICE` to hard-cap spending during volatile periods.

---

## Nonce Management

The `NonceManager` avoids fetching the nonce from the RPC on every
transaction.

**Behavior:**

1. First call: fetches `getTransactionCount` from the chain.
2. Subsequent calls: increments the local counter.
3. On any submission failure: resets to `null`, forcing a fresh fetch
   on the next call.

This prevents nonce gaps when transactions fail and avoids the
latency of an RPC round-trip on every submission.

**Edge case:** If the executor's wallet sends transactions from another
source (e.g., manual sends), the local nonce drifts. The reset-on-failure
mechanism self-corrects within one failed attempt.

---

## Retry Strategy

The `RetryManager` applies exponential backoff to failed operations.

| Attempt | Delay   |
|---------|---------|
| 1       | 1000 ms |
| 2       | 2000 ms |
| 3       | 4000 ms |

After 3 failed attempts, the key is abandoned until manually cleared
or until the next successful execution clears it.

Retry keys use the format `{workflowId}-{stepIndex}`, so retries are
scoped to a specific step of a specific workflow.

---

## Telemetry

### Logging

Structured JSON logging via `pino` with `pino-pretty` for readable
console output.

**Log levels:** `trace`, `debug`, `info`, `warn`, `error`, `fatal`

Set via `LOG_LEVEL` environment variable. Default is `info`.

**Key log events:**

| Level | Event                  | Fields                              |
|-------|------------------------|-------------------------------------|
| info  | Executor starting      | address, executorIndex              |
| info  | Scan complete          | readyCount                          |
| debug | Claimed workflow       | workflowId                          |
| debug | Simulation passed      | workflowId, gasEstimate             |
| warn  | Simulation failed      | workflowId, error                   |
| info  | Not profitable         | workflowId                          |
| info  | Transaction submitted  | workflowId, hash                    |
| info  | Transaction confirmed  | hash, status, gasUsed               |
| error | Submission failed      | workflowId, error                   |
| error | Confirmation failed    | hash, error                         |

### Metrics

In-memory counters tracked by the `Metrics` class. Printed on shutdown.

| Counter                  | Description                                    |
|--------------------------|------------------------------------------------|
| `successful_executions`  | Steps executed and confirmed on-chain          |
| `failed_executions`      | Transactions confirmed but with failure status |
| `simulation_failures`    | Steps that failed dry-run simulation           |
| `unprofitable_skips`     | Steps skipped due to low profitability         |

Metrics are not currently exported to an external system. For
production, connect to Prometheus, Datadog, or similar by extending
the `Metrics` class.

---

## Troubleshooting

### "NotExecutor" revert on submission

Your wallet address is not whitelisted. Ask the protocol owner to call
`addExecutor(yourAddress)` on all three contracts (WorkflowRegistry,
ExecutionEngine, RewardManager).

### Simulation always fails

- Confirm the workflow exists and is in `ACTIVE` status.
- Confirm the current step's delay condition is met.
- Check that the target contract of the step has not been destroyed or
  does not revert unconditionally.
- Set `LOG_LEVEL=debug` to see the simulation error message.

### Nonce too low / replacement transaction underpriced

The local nonce cache drifted from the chain. The executor self-heals
on the next cycle (nonce resets on failure). If persistent, check
whether another process is sending transactions from the same wallet.

### "Gas price exceeds cap, clamping"

The network's base fee exceeds half of your `MAX_GAS_PRICE`. Either:

1. Wait for gas to decrease.
2. Increase `MAX_GAS_PRICE` in your `.env`.

### Zero ready workflows on every scan

- Confirm workflows exist: `cast call $REGISTRY_ADDRESS "workflowCount()(uint256)"`.
- Confirm at least one is active and has remaining steps.
- Confirm delay conditions are met.
- Check that your RPC endpoint is responding and synced.

### Executor runs but never claims workflows

In multi-executor mode, verify `EXECUTOR_INDEX` and `TOTAL_EXECUTORS`
are set correctly. If `TOTAL_EXECUTORS` does not match the actual
number of executors, the hash distribution is uneven.
