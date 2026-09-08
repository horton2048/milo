import { MOODS, type MoodDefinition, type MoodId } from '../../core/model/Moods';
import {
  activeMoodIndex,
  ECHO_MOOD_ORBIT_TRAVEL_PX,
  moodOrbitTextPose,
  moodTickAngle,
  moodTickOpacity,
  nearestMoodPosition,
  orbitalMoodPose,
  wrapMoodIndex,
} from './MoodSwipeModel';
import { MoodPlanet } from './MoodPlanet';

const RING_DIAMETER = 240;
const TICK_RADIUS = 116;
const WORD_RADIUS = 132;
const PLANET_SIZE = 56;
const MOOD_LIST: Array<MoodDefinition> = MOODS as Array<MoodDefinition>;

interface Point {
  x: number;
  y: number;
}

/** Result callback when the user taps a mood. */
type SelectCallback = (index: number) => void;

/**
 * Echo-style continuous carousel: a ring of fifteen mood ticks, an orb at the
 * focus point, and an expandable word ring. Reuses the same math as the Web
 * build so positions and opacities match exactly.
 */
@Component
export struct MoodOrbitCarousel {
  @State dialPosition: number = 3;
  @State expanded: boolean = true;
  private onSelect: SelectCallback = (_index: number) => {};

  private get count(): number {
    return MOODS.length;
  }

  private get activeIndex(): number {
    return activeMoodIndex(this.dialPosition, this.count);
  }

  private get activeMoodId(): MoodId {
    return MOODS[this.activeIndex].id;
  }

  private get activeOrbOffsetY(): number {
    const pose = orbitalMoodPose(this.activeIndex, this.dialPosition, this.count);
    return pose.y;
  }

  private get activeOrbScale(): number {
    const pose = orbitalMoodPose(this.activeIndex, this.dialPosition, this.count);
    return pose.scale;
  }

  private get activeOrbZ(): number {
    const pose = orbitalMoodPose(this.activeIndex, this.dialPosition, this.count);
    return pose.zIndex;
  }

  private tickPoint(angle: number, radius: number): Point {
    const radians = (angle - 90) * (Math.PI / 180);
    const out: Point = {
      x: Math.cos(radians) * radius,
      y: Math.sin(radians) * radius,
    };
    return out;
  }

  private isTickActive(index: number): boolean {
    return wrapMoodIndex(index, this.count) === this.activeIndex;
  }

  private tickSize(index: number): number {
    return this.isTickActive(index) ? 8 : 5;
  }

  private tickColor(index: number): string {
    return this.isTickActive(index) ? '#c9befc' : '#8b87a6';
  }

  private tickOpacityValue(index: number): number {
    return moodTickOpacity(index, this.dialPosition, this.count);
  }

  private tickX(index: number): number {
    const angle = moodTickAngle(index, this.dialPosition, this.count);
    const point = this.tickPoint(angle, TICK_RADIUS);
    const size = this.tickSize(index);
    return RING_DIAMETER / 2 + point.x - size / 2;
  }

  private tickY(index: number): number {
    const angle = moodTickAngle(index, this.dialPosition, this.count);
    const point = this.tickPoint(angle, TICK_RADIUS);
    const size = this.tickSize(index);
    return RING_DIAMETER / 2 + point.y - size / 2;
  }

  private wordPose(index: number) {
    return moodOrbitTextPose(index, this.dialPosition, this.count, this.expanded);
  }

  private wordPoseVisible(index: number): boolean {
    return this.wordPose(index).visible;
  }

  private wordOpacity(index: number): number {
    return this.wordPose(index).opacity;
  }

  private wordScale(index: number): number {
    return this.wordPose(index).scale;
  }

  private wordX(index: number): number {
    const pose = this.wordPose(index);
    const point = this.tickPoint(pose.angle, WORD_RADIUS);
    return RING_DIAMETER / 2 + point.x - 30;
  }

  private wordY(index: number): number {
    const pose = this.wordPose(index);
    const point = this.tickPoint(pose.angle, WORD_RADIUS);
    return RING_DIAMETER / 2 + point.y - 10;
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Circle({ width: RING_DIAMETER, height: RING_DIAMETER })
        .fill(Color.Transparent)
        .stroke('rgba(139,124,246,0.20)')
        .strokeWidth(1)

      ForEach(MOOD_LIST, (mood: MoodDefinition, index: number) => {
        Circle({ width: this.tickSize(index), height: this.tickSize(index) })
          .fill(this.tickColor(index))
          .opacity(this.tickOpacityValue(index))
          .position({ x: this.tickX(index), y: this.tickY(index) })
          .onClick(() => {
            this.dialPosition = nearestMoodPosition(this.dialPosition, index, this.count);
            this.onSelect(index);
          })
      })

      ForEach(MOOD_LIST, (mood: MoodDefinition, index: number) => {
        if (this.wordPoseVisible(index)) {
          Text(mood.labels[0])
            .fontSize(11)
            .fontColor('#c9befc')
            .opacity(this.wordOpacity(index))
            .scale({ x: this.wordScale(index), y: this.wordScale(index) })
            .position({ x: this.wordX(index), y: this.wordY(index) })
            .width(60)
            .textAlign(TextAlign.Center)
            .onClick(() => {
              this.dialPosition = nearestMoodPosition(this.dialPosition, index, this.count);
              this.onSelect(index);
            })
        }
      })

      MoodPlanet({ moodId: this.activeMoodId, planetSize: PLANET_SIZE })
        .position({
          x: RING_DIAMETER / 2 - PLANET_SIZE / 2,
          y: RING_DIAMETER / 2 - PLANET_SIZE / 2 + this.activeOrbOffsetY,
        })
        .scale({ x: this.activeOrbScale, y: this.activeOrbScale })
        .zIndex(this.activeOrbZ)
        .onClick(() => {
          this.onSelect(this.activeIndex);
        })
    }
    .width(RING_DIAMETER + ECHO_MOOD_ORBIT_TRAVEL_PX * 2)
    .height(RING_DIAMETER + ECHO_MOOD_ORBIT_TRAVEL_PX * 2)
  }
}
