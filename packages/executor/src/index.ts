import 'dotenv/config';
import { loadConfig } from './config/index.js';
import { createClients } from './chain/provider.js';
import { createContracts } from './chain/contracts.js';
import { BlockMonitor } from './monitor/block-monitor.js';
import { WorkflowScanner } from './monitor/workflow-scanner.js';
import { TriggerEvaluator } from './scheduler/trigger-evaluator.js';
import { Simulator } from './execution/simulator.js';
import { GasEstimator } from './gas/gas-estimator.js';
import { Submitter } from './execution/submitter.js';
import { RetryManager } from './execution/retry-manager.js';
import { createLogger } from './telemetry/logger.js';
import { Metrics } from './telemetry/metrics.js';

async function main() {
  const logger = createLogger(process.env.LOG_LEVEL || 'info');
  const config = loadConfig();
  const metrics = new Metrics();

  logger.info('Starting Atlas Executor');

  const { publicClient, walletClient, account } = createClients(config);
  const { engine, registry } = createContracts(config, publicClient as any, walletClient as any);

  const blockMonitor = new BlockMonitor(publicClient as any, logger);
  const scanner = new WorkflowScanner(registry, engine, logger);
  const evaluator = new TriggerEvaluator(config.executorIndex, config.totalExecutors, logger);
  const simulator = new Simulator(publicClient as any, config.contracts.executionEngine, logger);
  const gasEstimator = new GasEstimator(publicClient as any, config.gas.maxGasPrice, logger);
  const submitter = new Submitter(walletClient as any, publicClient as any, config.contracts.executionEngine, logger);
  const retryManager = new RetryManager(logger);

  let processing = false;

  async function processWorkflows(blockNumber: bigint) {
    if (processing) return;
    processing = true;

    try {
      const readyWorkflows = await scanner.scanActiveWorkflows();
      const claimed = evaluator.filterByPriority(readyWorkflows, blockNumber);

      for (const wf of claimed) {
        const key = `${wf.workflowId}-${wf.currentStepIndex}`;

        // Simulate
        const sim = await simulator.simulate(wf.workflowId, account.address);
        if (!sim.success) {
          logger.warn({ workflowId: wf.workflowId.toString() }, 'Simulation failed, skipping');
          metrics.increment('simulation_failures');
          continue;
        }

        // Gas estimation + profitability
        const gas = await gasEstimator.estimate(sim.gasEstimate);
        if (!gasEstimator.isProfitable(wf.rewardPerStep, gas.estimatedCost, config.gas.profitabilityMultiplier)) {
          logger.info({ workflowId: wf.workflowId.toString() }, 'Not profitable, skipping');
          metrics.increment('unprofitable_skips');
          continue;
        }

        // Submit
        const hash = await submitter.submitExecution(wf.workflowId, gas);
        if (hash) {
          const success = await submitter.waitForConfirmation(hash);
          if (success) {
            metrics.increment('successful_executions');
            retryManager.clear(key);
          } else {
            metrics.increment('failed_executions');
          }
        }
      }
    } catch (err) {
      logger.error({ err }, 'Error processing workflows');
    } finally {
      processing = false;
    }
  }

  // Start monitoring
  await blockMonitor.start(async (blockNumber) => {
    // Only process on scan intervals (every ~6 blocks on Base = 12s)
    if (Number(blockNumber) % 6 === 0) {
      await processWorkflows(blockNumber);
    }
  });

  // Periodic full scan
  setInterval(async () => {
    const block = blockMonitor.getLatestBlock();
    await processWorkflows(block);
  }, config.polling.scanIntervalMs);

  // Graceful shutdown
  process.on('SIGINT', () => {
    logger.info('Shutting down...');
    blockMonitor.stop();
    logger.info(metrics.snapshot(), 'Final metrics');
    process.exit(0);
  });

  logger.info({ address: account.address, executorIndex: config.executorIndex }, 'Executor running');
}

main().catch(console.error);
