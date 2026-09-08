import { type Draft } from '../../core/model/Domain';
import { fallbackDiary } from '../conversation/FallbackGuide';
import {
  ConversationController,
  initialConversationState,
  type ConversationState,
} from '../conversation/ConversationController';

/**
 * First-person diary generated from the past-branch transcript. Prefers the AI
 * gateway via `ConversationController.createDiary`; on any failure the local
 * `fallbackDiary` runs so the user always sees a draft. The user can edit
 * before save.
 */
@Component
export struct DiaryScreen {
  @State diaryOn: boolean = true;
  @State diary: string = '';
  @State generating: boolean = true;
  @State editing: boolean = false;
  @State conversationState: ConversationState = initialConversationState();
  private draft: Draft = { mood: { valence: 0, labels: [] }, transcript: [], diaryEnabled: true };
  private controller: ConversationController | null = null;
  private onSave: (diary: string | undefined, enabled: boolean) => void = () => {};
  private onBack: () => void = () => {};

  aboutToAppear(): void {
    if (!this.diaryOn) {
      this.diary = '';
      this.generating = false;
      return;
    }
    this.generating = true;
    void this.generateDiary();
  }

  private async generateDiary(): Promise<void> {
    if (this.controller === null) {
      this.diary = fallbackDiary(this.draft);
      this.generating = false;
      return;
    }
    const result = await this.controller.createDiary(this.draft);
    this.conversationState = result.state;
    this.diary = result.diary;
    this.generating = false;
  }

  private get fallbackNotice(): string {
    if (this.conversationState.lastError === undefined) {
      return '';
    }
    return 'AI 暂时不可用，已为你用本地模板生成。';
  }

  build() {
    Column() {
      Row() {
        Button('← 返回对话')
          .backgroundColor(Color.Transparent)
          .fontColor('#c9befc')
          .fontSize(13)
          .onClick(() => this.onBack())
        Blank()
        Text(this.draft.timeMark ?? '')
          .fontColor('#c9befc')
          .fontSize(12)
        Blank()
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 8 })

      Column() {
        Text('显影这段回忆')
          .fontSize(22)
          .fontColor('#ffffff')
        Text('我们把刚才的对话，写成了一篇属于你的日记。')
          .fontSize(13)
          .fontColor('#8b87a6')
          .margin({ top: 8 })
      }
      .margin({ top: 16, bottom: 20 })

      if (this.fallbackNotice.length > 0) {
        Text(this.fallbackNotice)
          .fontSize(12)
          .fontColor('#c9befc')
          .backgroundColor('rgba(139,124,246,0.12)')
          .padding(8)
          .borderRadius(10)
          .margin({ left: 16, right: 16, bottom: 8 })
          .width('90%')
      }

      Row() {
        Column() {
          Text('沉淀为日记')
            .fontSize(14)
            .fontColor('#ffffff')
          Text('以你的视角书写；关闭则只保留对话记录')
            .fontSize(11)
            .fontColor('#8b87a6')
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        Button(this.diaryOn ? '●' : '○')
          .width(48)
          .height(28)
          .backgroundColor(this.diaryOn ? '#8b7cf6' : 'rgba(255,255,255,0.10)')
          .fontColor('#ffffff')
          .onClick(() => {
            this.diaryOn = !this.diaryOn;
            if (this.diaryOn && this.diary.length === 0) {
              this.generating = true;
              void this.generateDiary();
            }
          })
      }
      .width('90%')
      .padding(16)
      .borderRadius(14)
      .backgroundColor('rgba(255,255,255,0.04)')
      .margin({ bottom: 18 })

      if (this.diaryOn) {
        if (this.editing) {
          TextArea({ text: this.diary })
            .onChange((value: string) => {
              this.diary = value;
            })
            .width('90%')
            .height(220)
            .padding(12)
            .backgroundColor('rgba(255,255,255,0.05)')
            .fontColor('#ffffff')
            .margin({ bottom: 12 })
        } else if (this.generating && this.diary.length === 0) {
          Text('回忆正在显影…')
            .fontColor('#8b87a6')
            .margin({ bottom: 12 })
        } else {
          Text(this.diary)
            .width('90%')
            .padding(16)
            .backgroundColor('rgba(255,255,255,0.04)')
            .fontColor('#ffffff')
            .fontSize(14)
            .lineHeight(22)
            .margin({ bottom: 12 })
        }

        if (!this.generating) {
          Button(this.editing ? '完成编辑' : '修改一下措辞')
            .backgroundColor(Color.Transparent)
            .fontColor('#c9befc')
            .fontSize(14)
            .margin({ bottom: 12 })
            .onClick(() => {
              this.editing = !this.editing;
            })
        }
      }

      Button('收进回忆')
        .width('90%')
        .height(48)
        .backgroundColor('#8b7cf6')
        .fontColor('#ffffff')
        .enabled(!this.diaryOn || !this.generating)
        .opacity((!this.diaryOn || !this.generating) ? 1.0 : 0.5)
        .onClick(() => {
          this.onSave(this.diaryOn ? this.diary : undefined, this.diaryOn);
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#050608')
  }
}
