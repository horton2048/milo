/**
 * Deterministic starfield used as the home / empty-state backdrop.
 * Positions are seeded so screenshots stay stable across runs.
 */
export interface Star {
  x: number; // 0..1 horizontal fraction
  y: number; // 0..1 vertical fraction
  radius: number; // px radius
  opacity: number; // 0..1
}

function seedFrom(seed: number): () => number {
  let state = seed >>> 0;
  return (): number => {
    if (state === 0) {
      state = 0x9e3779b9;
    }
    state ^= state << 13;
    state ^= state >>> 17;
    state ^= state << 5;
    return ((state >>> 0) % 100000) / 100000;
  };
}

/** Returns `count` stars with stable positions for the given seed. */
export function generateStars(count: number, seed: number): Star[] {
  const rand = seedFrom(seed);
  const out: Star[] = [];
  for (let index = 0; index < count; index += 1) {
    const x = rand();
    const y = rand();
    const size = rand();
    const fade = rand();
    out.push({
      x: x,
      y: y,
      radius: 0.6 + size * 1.6,
      opacity: 0.25 + fade * 0.6,
    });
  }
  return out;
}

const DEFAULT_STARFIELD: Star[] = generateStars(120, 0x5a17c0fe);

@Component
export struct Starfield {
  @Prop count: number = 120;
  @Prop seed: number = 0x5a17c0fe;
  @Prop color: string = '#ffffff';

  private get stars(): Star[] {
    if (this.count === DEFAULT_STARFIELD.length && this.seed === 0x5a17c0fe) {
      return DEFAULT_STARFIELD;
    }
    return generateStars(this.count, this.seed);
  }

  build() {
    Stack() {
      ForEach(this.stars, (star: Star) => {
        Circle({ width: star.radius * 2, height: star.radius * 2 })
          .fill(this.color)
          .opacity(star.opacity)
          .position({ x: `${star.x * 100}%`, y: `${star.y * 100}%` })
      })
    }
    .width('100%')
    .height('100%')
  }
}
