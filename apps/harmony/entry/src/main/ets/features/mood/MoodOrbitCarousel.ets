import { curves } from '@kit.ArkUI';
import { MOODS, type MoodDefinition, type MoodId } from '../../core/model/Moods';
import {
  activeMoodIndex,
  ECHO_MOOD_ORBIT_TRAVEL_PX,
  moodOrbitTextPose,
  moodPointerAngle,
  moodPositionFromRotation,
  moodTickAngle,
  moodTickOpacity,
  nearestMoodPosition,
  orbitalMoodPose,
  projectMoodSnap,
  shortestMoodAngleDelta,
  wrapMoodIndex,
} from './MoodSwipeModel';
import { MoodPlanet } from './MoodPlanet';
import { MOOD_SHEET_HEIGHT, MOOD_SHEET_WIDTH } from '../../core/model/MoodAssets';
import { Haptics } from '../../core/system/Haptics';

const RING_DIAMETER = 240;
const TICK_RADIUS = 116;
const WORD_RADIUS = 132;
// Web reference: orb 244 on a 300 dial (81%); keep the same ratio on the 240 ring.
const PLANET_SIZE = 195;
const PLANET_HEIGHT = PLANET_SIZE * (MOOD_SHEET_HEIGHT / MOOD_SHEET_WIDTH);
// Web layering: orb z=30, ticks z=44, words z=46.
const TICK_Z_INDEX = 44;
const WORD_Z_INDEX = 46;
const CAROUSEL_SIZE = RING_DIAMETER + ECHO_MOOD_ORBIT_TRAVEL_PX * 2;
const RING_CENTER = CAROUSEL_SIZE / 2;
const MOOD_LIST: Array<MoodDefinition> = MOODS as Array<MoodDefinition>;
// Web reference: 28px dead zone on a 300px dial, scaled to our 240px ring.
const DRAG_DEAD_ZONE_VP = 22;
const SETTLE_DURATION_MS = 520;
const VELOCITY_WINDOW_MS = 100;

interface Point {
  x: number;
  y: number;
}

/** One rotation sample used to estimate fling velocity. */
interface RotationSample {
  rotation: number;
  time: number;
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
  @State dragging: boolean = false;
  onSelect: SelectCallback = (_index: number) => {};
  onActiveChange: SelectCallback = (_index: number) => {};
  private haptics: Haptics = new Haptics();
  private lastActiveIndex: number = 3;
  private gestureStartPosition: number = 3;
  private lastPointerAngle: number = 0;
  private hasPointerAngle: boolean = false;
  private accumulatedRotation: number = 0;
  private samples: Array<RotationSample> = [];

  private count(): number {
    return MOODS.length;
  }

  private activeIndex(): number {
    return activeMoodIndex(this.dialPosition, this.count());
  }

  /**
   * Single write path for the dial position. Fires the selection haptic and
   * notifies the host whenever the focused mood crosses a step boundary,
   * mirroring the web build's `updateEchoPosition`.
   */
  private updatePosition(next: number): void {
    this.dialPosition = next;
    const index = this.activeIndex();
    if (index !== this.lastActiveIndex) {
      this.lastActiveIndex = index;
      this.haptics.selection();
      this.onActiveChange(index);
    }
  }

  /** Animated settle used after fling, cancel and deliberate taps. */
  private settleTo(target: number): void {
    this.getUIContext().animateTo(
      {
        duration: SETTLE_DURATION_MS,
        curve: curves.cubicBezierCurve(0.22, 0.72, 0.18, 1),
      },
      () => {
        this.dragging = false;
        this.updatePosition(target);
      },
    );
  }

  private rememberSample(rotation: number, time: number): void {
    this.samples.push({ rotation: rotation, time: time });
    this.samples = this.samples.filter((sample: RotationSample) => time - sample.time <= VELOCITY_WINDOW_MS);
  }

  /** Finger position relative to the carousel; the center when unavailable. */
  private pointerLocalPoint(event: GestureEvent): Point {
    const fingers = event.fingerList;
    if (fingers.length === 0) {
      const center: Point = { x: RING_CENTER, y: RING_CENTER };
      return center;
    }
    const finger = fingers[0];
    const point: Point = { x: finger.localX, y: finger.localY };
    return point;
  }

  private trackPointer(event: GestureEvent, emit: boolean): void {
    const point = this.pointerLocalPoint(event);
    const dx = point.x - RING_CENTER;
    const dy = point.y - RING_CENTER;
    if (Math.hypot(dx, dy) < DRAG_DEAD_ZONE_VP) {
      return;
    }
    const angle = moodPointerAngle(point.x, point.y, RING_CENTER, RING_CENTER);
    if (!this.hasPointerAngle) {
      this.hasPointerAngle = true;
      this.lastPointerAngle = angle;
      this.rememberSample(this.accumulatedRotation, Date.now());
      return;
    }
    this.accumulatedRotation += shortestMoodAngleDelta(this.lastPointerAngle, angle);
    this.lastPointerAngle = angle;
    this.rememberSample(this.accumulatedRotation, Date.now());
    if (emit) {
      this.updatePosition(
        moodPositionFromRotation(this.gestureStartPosition, this.accumulatedRotation, this.count()),
      );
    }
  }

  private handleDragStart(event: GestureEvent): void {
    this.gestureStartPosition = this.dialPosition;
    this.accumulatedRotation = 0;
    this.hasPointerAngle = false;
    this.samples = [];
    this.dragging = true;
    this.trackPointer(event, false);
  }

  private handleDragUpdate(event: GestureEvent): void {
    this.trackPointer(event, true);
  }

  private positionVelocityPerMs(): number {
    const sampleCount = this.samples.length;
    if (sampleCount < 2) {
      return 0;
    }
    const first = this.samples[0];
    const last = this.samples[sampleCount - 1];
    const elapsed = last.time - first.time;
    if (elapsed <= 0) {
      return 0;
    }
    const rotationVelocity = (last.rotation - first.rotation) / elapsed;
    return -rotationVelocity / (360 / this.count());
  }

  private handleDragEnd(): void {
    const target = projectMoodSnap(this.dialPosition, this.positionVelocityPerMs());
    this.settleTo(target);
  }

  private handleDragCancel(): void {
    this.settleTo(projectMoodSnap(this.dialPosition, 0));
  }

  /** Animated select used by tick and word taps (web: `selectEchoMood`). */
  private selectIndex(index: number): void {
    this.expanded = true;
    this.settleTo(nearestMoodPosition(this.dialPosition, index, this.count()));
    this.onSelect(index);
  }

  private activeMoodId(): MoodId {
    return MOODS[this.activeIndex()].id;
  }

  private activeOrbOffsetX(): number {
    const pose = orbitalMoodPose(this.activeIndex(), this.dialPosition, this.count());
    return pose.x;
  }

  private activeOrbOffsetY(): number {
    const pose = orbitalMoodPose(this.activeIndex(), this.dialPosition, this.count());
    return pose.y;
  }

  private activeOrbScale(): number {
    const pose = orbitalMoodPose(this.activeIndex(), this.dialPosition, this.count());
    return pose.scale;
  }

  private activeOrbZ(): number {
    const pose = orbitalMoodPose(this.activeIndex(), this.dialPosition, this.count());
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
    return wrapMoodIndex(index, this.count()) === this.activeIndex();
  }

  private tickSize(index: number): number {
    return this.isTickActive(index) ? 8 : 5;
  }

  private tickColor(index: number): string {
    return this.isTickActive(index) ? '#c9befc' : '#8b87a6';
  }

  private tickOpacityValue(index: number): number {
    return moodTickOpacity(index, this.dialPosition, this.count());
  }

  private tickX(index: number): number {
    const angle = moodTickAngle(index, this.dialPosition, this.count());
    const point = this.tickPoint(angle, TICK_RADIUS);
    const size = this.tickSize(index);
    return RING_CENTER + point.x - size / 2;
  }

  private tickY(index: number): number {
    const angle = moodTickAngle(index, this.dialPosition, this.count());
    const point = this.tickPoint(angle, TICK_RADIUS);
    const size = this.tickSize(index);
    return RING_CENTER + point.y - size / 2;
  }

  private wordPose(index: number) {
    return moodOrbitTextPose(index, this.dialPosition, this.count(), this.expanded);
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
    return RING_CENTER + point.x - 30;
  }

  private wordY(index: number): number {
    const pose = this.wordPose(index);
    const point = this.tickPoint(pose.angle, WORD_RADIUS);
    return RING_CENTER + point.y - 10;
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Circle({ width: RING_DIAMETER, height: RING_DIAMETER })
        .fill(Color.Transparent)
        .stroke(this.dragging ? 'rgba(201,190,252,0.34)' : 'rgba(139,124,246,0.20)')
        .strokeWidth(this.dragging ? 1.5 : 1)

      ForEach(MOOD_LIST, (mood: MoodDefinition, index: number) => {
        Circle({ width: this.tickSize(index), height: this.tickSize(index) })
          .fill(this.tickColor(index))
          .opacity(this.tickOpacityValue(index))
          .position({ x: this.tickX(index), y: this.tickY(index) })
          .zIndex(TICK_Z_INDEX)
          .onClick(() => {
            this.selectIndex(index);
          })
      })

      ForEach(MOOD_LIST, (mood: MoodDefinition, index: number) => {
        Text(mood.labels[0])
          .fontSize(11)
          .fontColor('#c9befc')
          .opacity(this.wordOpacity(index))
          .scale({ x: this.wordScale(index), y: this.wordScale(index) })
          .position({ x: this.wordX(index), y: this.wordY(index) })
          .width(60)
          .textAlign(TextAlign.Center)
          .zIndex(WORD_Z_INDEX)
          .visibility(this.wordPoseVisible(index) ? Visibility.Visible : Visibility.Hidden)
          .onClick(() => {
            this.selectIndex(index);
          })
      })

      MoodPlanet({ moodId: this.activeMoodId(), planetSize: PLANET_SIZE })
        .position({
          x: RING_CENTER - PLANET_SIZE / 2 + this.activeOrbOffsetX(),
          y: RING_CENTER - PLANET_HEIGHT / 2 + this.activeOrbOffsetY(),
        })
        .scale({ x: this.activeOrbScale(), y: this.activeOrbScale() })
        .zIndex(this.activeOrbZ())
        .onClick(() => {
          this.haptics.selection();
          this.onSelect(this.activeIndex());
        })
    }
    .width(CAROUSEL_SIZE)
    .height(CAROUSEL_SIZE)
    .gesture(
      PanGesture({ fingers: 1, direction: PanDirection.All, distance: 5 })
        .onActionStart((event: GestureEvent) => {
          this.handleDragStart(event);
        })
        .onActionUpdate((event: GestureEvent) => {
          this.handleDragUpdate(event);
        })
        .onActionEnd(() => {
          this.handleDragEnd();
        })
        .onActionCancel(() => {
          this.handleDragCancel();
        })
    )
  }
}
