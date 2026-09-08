import { type ChatMessage, type Draft } from '../../core/model/Domain';
import { FallbackGuide } from './FallbackGuide';

/**
 * Past-branch guided conversation. Opens with the scripted welcome from
 * `FallbackGuide`, then keeps the offline guide running. When the user has
 * spoken and the guide is wrapping up, the "沉淀这段回忆" button appears.
 */
@Component
export struct ChatScreen {
  @State messages: ChatMessage[] = [];
  @State input: string = '';
  @State busy: boolean = true;
  private guide: FallbackGuide | null = null;
  private draft: Draft = { mood: { valence: 0, labels: [] }, transcript: [], diaryEnabled: true };
  private onFinish: (transcript: ChatMessage[]) => void = () => {};
  private onBack: () => void = () => {};
  private onSend: (text: string) => void = () => {};

  aboutToAppear(): void {
    const timeMark = this.draft.timeMark ?? '过去的某一天';
    this.guide = new FallbackGuide(timeMark);
    this.messages = [];
    this.pushMessage({ role: 'ai', text: this.guide.opening(), ts: Date.now() });
    this.busy = false;
  }

  private pushMessage(message: ChatMessage): void {
    const next: ChatMessage[] = [];
    for (let index = 0; index < this.messages.length; index += 1) {
      next.push(this.messages[index]);
    }
    next.push(message);
    this.messages = next;
  }

  private get userSpoke(): boolean {
    for (let index = 0; index < this.messages.length; index += 1) {
      if (this.messages[index].role === 'user') {
        return true;
      }
    }
    return false;
  }

  private get canFinish(): boolean {
    if (!this.userSpoke) {
      return false;
    }
    if (this.guide === null) {
      return false;
    }
    return this.guide.isWrappingUp();
  }

  build() {
    Column() {
      Row() {
        Button('← 离开')
          .backgroundColor(Color.Transparent)
          .fontColor('#c9befc')
          .fontSize(13)
          .onClick(() => this.onBack())
        Blank()
        Text(this.draft.timeMark ?? '')
          .fontColor('#c9befc')
          .fontSize(12)
        Blank()
        Text('引导')
          .fontColor('#8b87a6')
          .fontSize(12)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 8 })

      List({ space: 12 }) {
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

      if (this.canFinish) {
        Button('✦ 沉淀这段回忆')
          .width('90%')
          .height(44)
          .margin({ top: 8, bottom: 8 })
          .backgroundColor('rgba(139,124,246,0.5)')
          .fontColor('#c9befc')
          .onClick(() => this.onFinish(this.messages))
      }

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
            if (this.guide !== null) {
              this.pushMessage({ role: 'ai', text: this.guide.next(), ts: Date.now() });
            }
            this.busy = false;
          })
      }
      .width('90%')
      .padding({ left: 0, right: 0, top: 8, bottom: 12 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#050608')
  }
}
