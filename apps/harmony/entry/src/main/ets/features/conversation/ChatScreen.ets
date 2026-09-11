import { curves } from '@kit.ArkUI';
import { type ChatMessage, type Draft } from '../../core/model/Domain';
import { FallbackGuide } from './FallbackGuide';
import { TypingDots } from '../ui/TypingDots';
import {
  ConversationController,
  initialConversationState,
  type ConversationState,
} from './ConversationController';

/** AI-mode conversations stop after this many exchanges. */
const MAX_AI_TURNS: number = 3;

/** Web `cubic-bezier(0.22, 1, 0.36, 1)` — the signature Milo ease. */
const MILO_EASE: ICurve = curves.cubicBezierCurve(0.22, 1, 0.36, 1);

const INK: string = '#eae6ff';
const INK_FAINT: string = 'rgba(234,230,255,0.60)';
const INK_INTERACTIVE: string = 'rgba(238,234,255,0.78)';
const GLASS_BG: string = 'rgba(255,255,255,0.06)';
const GLASS_BORDER: string = 'rgba(255,255,255,0.12)';

/**
 * Past-branch guided conversation, styled 1:1 after the Web `Chat.tsx` screen.
 * The top-left "AI" pill toggles AI mode (default off → scripted guide only).
 * AI conversations are capped at MAX_AI_TURNS exchanges, after which the
 * closing line and the "沉淀这段回忆" button appear and the input is retired.
 */
@Component
export struct ChatScreen {
  @State messages: ChatMessage[] = [];
  @State input: string = '';
  @State busy: boolean = false;
  @State aiMode: boolean = false;
  @State aiTurns: number = 0;
  @State conversationDone: boolean = false;
  @State conversationState: ConversationState = initialConversationState();
  private guide: FallbackGuide | null = null;
  private scroller: Scroller = new Scroller();
  controller: ConversationController | null = null;
  draft: Draft = { mood: { valence: 0, labels: [] }, transcript: [], diaryEnabled: true };
  onFinish: (transcript: ChatMessage[]) => void = () => {};
  onBack: () => void = () => {};
  onSend: (text: string) => void = () => {};

  aboutToAppear(): void {
    const timeMark = this.draft.timeMark ?? '过去的某一天';
    this.guide = new FallbackGuide(timeMark);
    if (this.controller !== null) {
      this.controller.restoreState(this.conversationState);
    }
    this.messages = [];
    this.aiTurns = 0;
    this.conversationDone = false;
    this.pushMessage({ role: 'ai', text: this.guide.opening(), ts: Date.now() });
  }

  private async sendReply(text: string): Promise<void> {
    if (this.conversationDone) {
      return;
    }
    if (this.aiMode) {
      if (this.controller === null || this.aiTurns >= MAX_AI_TURNS) {
        this.finishConversation();
        return;
      }
      const result = await this.controller.respond(this.draft, text, Date.now());
      this.conversationState = result.state;
      this.pushMessage(result.message);
      this.aiTurns += 1;
      if (this.aiTurns >= MAX_AI_TURNS) {
        this.finishConversation();
      }
      return;
    }
    if (this.guide === null) {
      return;
    }
    this.pushMessage({ role: 'ai', text: this.guide.next(), ts: Date.now() });
  }

  private finishConversation(): void {
    if (this.conversationDone) {
      return;
    }
    this.conversationDone = true;
    if (this.guide !== null) {
      this.pushMessage({ role: 'ai', text: this.guide.closing(), ts: Date.now() });
    }
  }

  private pushMessage(message: ChatMessage): void {
    const next: ChatMessage[] = [];
    for (let index = 0; index < this.messages.length; index += 1) {
      next.push(this.messages[index]);
    }
    next.push(message);
    this.messages = next;
    this.scrollToEnd();
  }

  private scrollToEnd(): void {
    setTimeout(() => {
      this.scroller.scrollEdge(Edge.Bottom);
    }, 60);
  }

  private canFinish(): boolean {
    if (this.conversationDone) {
      return true;
    }
    if (this.aiMode) {
      return false;
    }
    return this.guide !== null && this.guide.isWrappingUp();
  }

  private sendCurrent(): void {
    const text = this.input.trim();
    if (text.length === 0 || this.busy || this.conversationDone) {
      return;
    }
    this.input = '';
    this.busy = true;
    this.pushMessage({ role: 'user', text: text, ts: Date.now() });
    this.onSend(text);
    void this.sendReply(text).then(() => {
      this.busy = false;
    });
  }

  private fallbackNotice(): string {
    const error = this.conversationState.lastError;
    if (error === undefined) {
      return '';
    }
    if (error.retryable) {
      return 'AI 暂时不可用，已切换到引导式回响。';
    }
    return '对话内容需要换个方向，已回到本地引导。';
  }

  build() {
    Column() {
      Row() {
        Text('← 离开')
          .fontSize(14)
          .fontColor(INK_INTERACTIVE)
          .onClick(() => this.onBack())
        Text(this.aiMode ? '✦ AI' : 'AI')
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.aiMode ? '#050608' : '#8b87a6')
          .backgroundColor(this.aiMode ? '#8b7cf6' : 'rgba(139,124,246,0.14)')
          .borderRadius(13)
          .height(26)
          .padding({ left: 10, right: 10 })
          .margin({ left: 12 })
          .onClick(() => {
            this.aiMode = !this.aiMode;
          })
        Blank()
        Text(this.draft.timeMark ?? '')
          .fontSize(12)
          .fontColor(INK_FAINT)
          .letterSpacing(5)
        Blank()
        Text(this.aiMode ? '回响' : '引导')
          .fontSize(12)
          .fontColor(INK_FAINT)
          .width(48)
          .textAlign(TextAlign.End)
      }
      .width('100%')
      .padding({ bottom: 14 })

      if (this.fallbackNotice().length > 0) {
        Text(this.fallbackNotice())
          .fontSize(12)
          .fontColor('#c9befc')
          .backgroundColor('rgba(139,124,246,0.12)')
          .padding(8)
          .borderRadius(10)
          .margin({ bottom: 10 })
          .width('100%')
      }

      List({ space: 14, scroller: this.scroller }) {
        ForEach(this.messages, (message: ChatMessage) => {
          ListItem() {
            Text(message.text)
              .fontSize(14.5)
              .lineHeight(26.8)
              .fontColor(INK)
              .padding({ left: 17, right: 17, top: 13, bottom: 13 })
              .borderRadius({
                topLeft: 20,
                topRight: 20,
                bottomLeft: message.role === 'ai' ? 6 : 20,
                bottomRight: message.role === 'user' ? 6 : 20,
              })
              .backgroundColor(message.role === 'user' ? 'rgba(255,255,255,0.09)' : 'rgba(139,124,246,0.14)')
              .border({
                width: 1,
                color: message.role === 'user' ? 'rgba(255,255,255,0.13)' : 'rgba(139,124,246,0.25)',
              })
              .constraintSize({ maxWidth: '82%' })
              .transition(
                TransitionEffect.OPACITY
                  .combine(TransitionEffect.translate({ y: 10 }))
                  .animation({ duration: 500, curve: MILO_EASE }),
              )
          }
          .width('100%')
          .alignSelf(message.role === 'user' ? ItemAlign.End : ItemAlign.Start)
        }, (message: ChatMessage) => `${message.ts}-${message.role}`)
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 2, right: 2, top: 8, bottom: 16 })

      if (this.busy) {
        Column() {
          TypingDots()
        }
        .padding({ left: 17, right: 17, top: 13, bottom: 13 })
        .borderRadius({ topLeft: 20, topRight: 20, bottomLeft: 6, bottomRight: 20 })
        .backgroundColor('rgba(139,124,246,0.14)')
        .border({ width: 1, color: 'rgba(139,124,246,0.25)' })
        .alignSelf(ItemAlign.Start)
        .width('100%')
      }

      if (this.canFinish()) {
        Button('✦ 沉淀这段回忆')
          .width('100%')
          .height(52)
          .borderRadius(999)
          .backgroundColor(Color.Transparent)
          .linearGradient({
            angle: 180,
            colors: [
              ['rgba(255,255,255,0.12)', 0],
              ['rgba(255,255,255,0.04)', 0.45],
              ['rgba(255,255,255,0.02)', 1],
            ],
          })
          .border({ width: 1, color: 'rgba(139,124,246,0.5)' })
          .fontColor('#c9befc')
          .fontSize(15)
          .margin({ bottom: 12 })
          .onClick(() => this.onFinish(this.messages))
      }

      if (!this.conversationDone) {
        Row({ space: 10 }) {
          TextInput({ placeholder: '说说那时的事…', text: this.input })
            .onChange((value: string) => {
              this.input = value;
            })
            .onSubmit((enterKey: EnterKeyType) => {
              this.sendCurrent();
            })
            .layoutWeight(1)
            .height(44)
            .padding({ left: 8, right: 8, top: 10, bottom: 10 })
            .backgroundColor(Color.Transparent)
            .fontColor(INK)
            .fontSize(15)
            .placeholderColor('rgba(234,230,255,0.64)')
            .placeholderFont({ size: 15 })
            .caretColor('#c9befc')
          Button('↑')
            .width(44)
            .height(44)
            .borderRadius(22)
            .backgroundColor(GLASS_BG)
            .border({ width: 1, color: GLASS_BORDER })
            .fontColor(INK)
            .fontSize(18)
            .opacity(this.input.trim().length > 0 && !this.busy ? 1 : 0.48)
            .enabled(this.input.trim().length > 0 && !this.busy)
            .onClick(() => {
              this.sendCurrent();
            })
        }
        .width('100%')
        .padding(10)
        .borderRadius(24)
        .backgroundColor(GLASS_BG)
        .border({ width: 1, color: GLASS_BORDER })
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 24, right: 24, top: 20, bottom: 24 })
    .backgroundColor('#050608')
    .transition(
      TransitionEffect.OPACITY
        .combine(TransitionEffect.translate({ y: 12 }))
        .animation({ duration: 900, curve: MILO_EASE }),
    )
  }
}
