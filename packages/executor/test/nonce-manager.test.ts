import { describe, it, expect, vi } from 'vitest';
import { NonceManager } from '../src/nonce/nonce-manager.js';

describe('NonceManager', () => {
  it('fetches nonce from chain on first call', async () => {
    const mockClient = {
      getTransactionCount: vi.fn().mockResolvedValue(5),
    };
    const manager = new NonceManager(mockClient as any, '0x1234' as any, { debug: vi.fn() } as any);

    const nonce = await manager.getNextNonce();
    expect(nonce).toBe(5);
    expect(mockClient.getTransactionCount).toHaveBeenCalledOnce();
  });

  it('increments nonce locally on subsequent calls', async () => {
    const mockClient = {
      getTransactionCount: vi.fn().mockResolvedValue(10),
    };
    const manager = new NonceManager(mockClient as any, '0x1234' as any, { debug: vi.fn() } as any);

    const n1 = await manager.getNextNonce();
    const n2 = await manager.getNextNonce();
    const n3 = await manager.getNextNonce();

    expect(n1).toBe(10);
    expect(n2).toBe(11);
    expect(n3).toBe(12);
    expect(mockClient.getTransactionCount).toHaveBeenCalledOnce();
  });

  it('resets to null and re-fetches after reset()', async () => {
    const mockClient = {
      getTransactionCount: vi.fn().mockResolvedValueOnce(5).mockResolvedValueOnce(20),
    };
    const manager = new NonceManager(mockClient as any, '0x1234' as any, { debug: vi.fn() } as any);

    await manager.getNextNonce(); // 5
    manager.reset();
    const n2 = await manager.getNextNonce(); // re-fetches → 20

    expect(n2).toBe(20);
    expect(mockClient.getTransactionCount).toHaveBeenCalledTimes(2);
  });
});
