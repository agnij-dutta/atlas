import { describe, it, expect } from 'vitest';
import { GasEstimator } from '../src/gas/gas-estimator.js';

describe('GasEstimator', () => {
  it('isProfitable returns true when reward exceeds gas cost * multiplier', () => {
    const estimator = new GasEstimator(null as any, 50000000000n, null as any);
    // reward = 1000, gasCost = 500, multiplier = 1.2 → threshold = 600 → profitable
    expect(estimator.isProfitable(1000n, 500n, 1.2)).toBe(true);
  });

  it('isProfitable returns false when reward is below threshold', () => {
    const estimator = new GasEstimator(null as any, 50000000000n, null as any);
    // reward = 100, gasCost = 500, multiplier = 1.2 → threshold = 600 → not profitable
    expect(estimator.isProfitable(100n, 500n, 1.2)).toBe(false);
  });

  it('isProfitable handles edge case where reward equals threshold', () => {
    const estimator = new GasEstimator(null as any, 50000000000n, null as any);
    // reward = 600, gasCost = 500, multiplier = 1.2 → threshold = 600 → exactly profitable
    expect(estimator.isProfitable(600n, 500n, 1.2)).toBe(true);
  });
});
