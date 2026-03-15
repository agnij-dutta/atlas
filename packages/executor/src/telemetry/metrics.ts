export class Metrics {
  private counters = new Map<string, number>();
  private gauges = new Map<string, number>();

  increment(name: string, value = 1): void {
    this.counters.set(name, (this.counters.get(name) || 0) + value);
  }

  gauge(name: string, value: number): void {
    this.gauges.set(name, value);
  }

  getCounter(name: string): number {
    return this.counters.get(name) || 0;
  }

  getGauge(name: string): number {
    return this.gauges.get(name) || 0;
  }

  snapshot(): Record<string, number> {
    const result: Record<string, number> = {};
    for (const [k, v] of this.counters) result[`counter.${k}`] = v;
    for (const [k, v] of this.gauges) result[`gauge.${k}`] = v;
    return result;
  }
}
