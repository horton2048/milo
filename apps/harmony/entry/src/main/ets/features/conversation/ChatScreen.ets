import { type ChatMessage, type Draft } from '../../core/model/Domain';
import { FallbackGuide } from './FallbackGuide';
import {
  ConversationController,
  initialConversationState,
  type ConversationState,
} from './ConversationController';

/** AI-mode conversations stop after this many exchanges. */
const MAX_AI_TURNS: number = 3;

/**
 * Past-branch guided conversation. The top-left "AI" pill toggles AI mode
 * (default off → scripted guide only). AI conversations are capped at
 * MAX_AI_TURNS exchanges, after which the closing line and the
 * "沉淀这段回忆" button appear and the input is retired. The message list
 * scrolls to the newest entry on every update.
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
        Button('← 离开')
          .backgroundColor(Color.Transparent)
          .fontColor('#c9befc')
          .fontSize(13)
          .onClick(() => this.onBack())
        Button(this.aiMode ? '✦ AI' : 'AI')
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.aiMode ? '#050608' : '#8b87a6')
          .backgroundColor(this.aiMode ? '#8b7cf6' : 'rgba(139,124,246,0.14)')
          .borderRadius(13)
          .height(26)
          .padding({ left: 10, right: 10 })
          .margin({ left: 8 })
          .onClick(() => {
            this.aiMode = !this.aiMode;
          })
        Blank()
        Text(this.draft.timeMark ?? '')
          .fontColor('#c9befc')
          .fontSize(12)
        Blank()
        Text(this.aiMode ? '回响' : '引导')
          .fontColor('#8b87a6')
          .fontSize(12)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 8 })

      if (this.fallbackNotice().length > 0) {
        Text(this.fallbackNotice())
          .fontSize(12)
          .fontColor('#c9befc')
          .backgroundColor('rgba(139,124,246,0.12)')
          .padding(8)
          .borderRadius(10)
          .margin({ left: 16, right: 16, bottom: 8 })
          .width('90%')
      }

      List({ space: 12, scroller: this.scroller }) {
        ForEach(this.messages, (message: ChatMessage) => {
          ListItem() {
            Text(message.text)
              .padding(12)
              .borderRadius(14)
              .backgroundColor(message.role === 'user' ? 'rgba(139,124,246,0.20)' : 'rgba(255,255,255,0.06)')
              .fontColor('#ffffff')
              .fontSize(15)
              .maxLines(20)
              .constraintSize({ maxWidth: '82%' })
          }
          .width('100%')
          .alignSelf(message.role === 'user' ? ItemAlign.End : ItemAlign.Start)
        })
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 16, right: 16 })

      if (this.busy) {
        Text('回响正在倾听…')
          .fontSize(12)
          .fontColor('#8b87a6')
          .padding({ top: 4, bottom: 6 })
      }

      if (this.canFinish()) {
        Button('✦ 沉淀这段回忆')
          .width('90%')
          .height(44)
          .margin({ top: 8, bottom: 8 })
          .backgroundColor('rgba(139,124,246,0.5)')
          .fontColor('#c9befc')
          .onClick(() => this.onFinish(this.messages))
      }

      if (!this.conversationDone) {
        Row({ space: 8 }) {
          TextInput({ placeholder: '说说那时的事…', text: this.input })
            .onChange((value: string) => {
              this.input = value;
            })
            .layoutWeight(1)
            .height(44)
            .padding(12)
            .backgroundColor('rgba(255,255,255,0.05)')
            .fontColor('#ffffff')
          Button('↑')
            .width(44)
            .height(44)
            .backgroundColor('#8b7cf6')
            .fontColor('#ffffff')
            .enabled(this.input.trim().length > 0 && !this.busy)
            .onClick(() => {
              const text = this.input.trim();
              if (text.length === 0 || this.busy) {
                return;
              }
              this.input = '';
              this.busy = true;
              this.pushMessage({ role: 'user', text: text, ts: Date.now() });
              this.onSend(text);
              void this.sendReply(text).then(() => {
                this.busy = false;
              });
            })
        }
        .width('90%')
        .padding({ left: 0, right: 0, top: 8, bottom: 12 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#050608')
  }
}
