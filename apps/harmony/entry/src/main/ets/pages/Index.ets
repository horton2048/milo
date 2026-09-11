import {
  type DiaryEntry,
  type MoodId,
  type ChatMessage,
  type StickerTemplateId,
  Screen,
} from '../core/model/Domain';
import {
  initialRecallState,
  RecallEvents,
  transition,
  type RecallState,
} from '../core/flow/RecallMachine';
import { PreferencesKVStorage, type KVStorage } from '../core/data/KVStorage';
import { EntryRepository } from '../core/data/EntryRepository';
import { RecallSessionRepository } from '../core/data/RecallSessionRepository';
import { HomeScreen } from '../features/home/HomeScreen';
import { ClassifyScreen } from '../features/recall/ClassifyScreen';
import { NowNoteScreen } from '../features/recall/NowNoteScreen';
import { PastTimeScreen } from '../features/recall/PastTimeScreen';
import { ChatScreen } from '../features/conversation/ChatScreen';
import { DiaryScreen } from '../features/diary/DiaryScreen';
import { TimelineScreen } from '../features/timeline/TimelineScreen';
import { DetailScreen } from '../features/timeline/DetailScreen';
import { CardScreen } from '../features/timeline/CardScreen';
import {
  type AiGatewayClient,
  HttpAiGatewayClient,
  type FetchLike,
} from '../core/network/AiGatewayClient';
import { ConversationController } from '../features/conversation/ConversationController';
import { FallbackGuide } from '../features/conversation/FallbackGuide';
import { isGatewayConfigured, readAppConfig } from '../core/config/AppConfig';
import { HarmonyHttpFetcher } from '../core/network/HarmonyHttpFetcher';

@Entry
@Component
struct Index {
  // 状态 & 仓储
  @State state: RecallState = initialRecallState();
  @State entries: DiaryEntry[] = [];
  @State detailEntry: DiaryEntry | undefined = undefined;
  @State cardEntry: DiaryEntry | undefined = undefined;
  private storage: KVStorage = new PreferencesKVStorage(getContext(this));
  private entryRepo: EntryRepository = new EntryRepository(this.storage);
  private draftRepo: RecallSessionRepository = new RecallSessionRepository(this.storage);
  private gateway: AiGatewayClient | null = null;
  private hasRestored: boolean = false;

  aboutToAppear(): void {
    this.refreshEntries();
    if (!this.hasRestored) {
      this.hasRestored = true;
      const saved = this.draftRepo.loadDraft();
      if (saved !== undefined) {
        this.state = saved;
      }
    }
    this.refreshEntryCaches();
  }

  private buildChatController(): ConversationController {
    if (this.gateway === null) {
      this.gateway = this.createGateway();
    }
    const gateway = this.gateway;
    return new ConversationController({
      gateway: gateway,
      newGuide: (d) => new FallbackGuide(d.timeMark ?? '过去的某一天'),
    });
  }

  private createGateway(): AiGatewayClient {
    const config = readAppConfig();
    if (!isGatewayConfigured(config)) {
      return new HttpAiGatewayClient({
        baseUrl: config.gatewayBaseUrl,
        bearerToken: config.gatewayBearerToken,
        timeoutMs: 1500,
        fetcher: offlineFetcher,
      });
    }
    return new HttpAiGatewayClient({
      baseUrl: config.gatewayBaseUrl,
      bearerToken: config.gatewayBearerToken,
      timeoutMs: config.gatewayTimeoutMs,
      fetcher: new HarmonyHttpFetcher(),
    });
  }

  private refreshEntries(): void {
    this.entries = this.entryRepo.list();
  }

  private refreshEntryCaches(): void {
    const id = this.state.screen.entryId;
    if (this.state.screen.name === 'detail' && id !== undefined) {
      this.detailEntry = this.entryRepo.get(id);
    } else {
      this.detailEntry = undefined;
    }
    if (this.state.screen.name === 'card' && id !== undefined) {
      this.cardEntry = this.entryRepo.get(id);
    } else {
      this.cardEntry = undefined;
    }
  }

  private persistDraft(): void {
    this.draftRepo.saveDraft(this.state);
  }

  private clearDraft(): void {
    this.draftRepo.clearDraft();
  }

  private pickMood(moodId: MoodId): void {
    const next = transition(this.state, RecallEvents.selectMood(moodId));
    if (next !== this.state) {
      this.state = next;
      this.persistDraft();
    }
  }

  private classify(kind: 'now' | 'past'): void {
    const next = transition(this.state, RecallEvents.classify(kind));
    if (next !== this.state) {
      this.state = next;
      this.persistDraft();
    }
  }

  private setNote(value: string): void {
    const next = transition(this.state, RecallEvents.setNote(value));
    if (next !== this.state) {
      this.state = next;
      this.persistDraft();
    }
  }

  private setTimeMark(value: string): void {
    const next = transition(this.state, RecallEvents.setTimeMark(value));
    if (next !== this.state) {
      this.state = next;
      this.persistDraft();
    }
  }

  private sendMessage(text: string): void {
    const next = transition(this.state, RecallEvents.appendMessage('user', text, Date.now()));
    if (next !== this.state) {
      this.state = next;
      this.persistDraft();
    }
  }

  private saveNowEntry(note: string): void {
    const entry: DiaryEntry = {
      id: `now-${Date.now()}`,
      createdAt: Date.now(),
      kind: 'now',
      mood: this.state.draft.mood,
      diaryEnabled: false,
    };
    if (note.length > 0) {
      entry.note = note;
    }
    this.entryRepo.save(entry);
    this.clearDraft();
    this.state = transition(this.state, RecallEvents.reset());
    this.refreshEntries();
  }

  private savePastEntry(diary: string | undefined, diaryEnabled: boolean): void {
    const draft = this.state.draft;
    const entry: DiaryEntry = {
      id: `past-${Date.now()}`,
      createdAt: Date.now(),
      kind: 'past',
      mood: draft.mood,
      diaryEnabled: diaryEnabled,
      transcript: draft.transcript.slice(),
    };
    if (draft.timeMark !== undefined) {
      entry.timeMark = draft.timeMark;
    }
    if (diary !== undefined) {
      entry.diary = diary;
    }
    this.entryRepo.save(entry);
    this.clearDraft();
    this.state = transition(this.state, RecallEvents.reset());
    this.refreshEntries();
  }

  private openDetail(entryId: string): void {
    const next = transition(this.state, RecallEvents.openDetail(entryId));
    if (next !== this.state) {
      this.state = next;
      this.refreshEntryCaches();
    }
  }

  private back(): void {
    const next = transition(this.state, RecallEvents.back());
    if (next !== this.state) {
      this.state = next;
      this.refreshEntryCaches();
      this.persistDraft();
    }
  }

  build() {
    Stack() {
      if (this.state.screen.name === 'home') {
        HomeScreen({
          entryCount: this.entries.length,
          onSelectMood: (id: MoodId) => this.pickMood(id),
          onOpenTimeline: () => {
            this.state = transition(this.state, RecallEvents.openTimeline());
          },
        })
      } else if (this.state.screen.name === 'classify') {
        ClassifyScreen({
          onNow: () => this.classify('now'),
          onPast: () => this.classify('past'),
          onBack: () => this.back(),
        })
      } else if (this.state.screen.name === 'now-note') {
        NowNoteScreen({
          mood: this.state.draft.mood,
          onSave: (note: string) => this.saveNowEntry(note),
          onBack: () => this.back(),
        })
      } else if (this.state.screen.name === 'past-time') {
        PastTimeScreen({
          onNext: (mark: string) => this.setTimeMark(mark),
          onBack: () => this.back(),
        })
      } else if (this.state.screen.name === 'chat') {
        ChatScreen({
          draft: this.state.draft,
          controller: this.buildChatController(),
          onFinish: (_transcript: ChatMessage[]) => {
            const next = transition(this.state, RecallEvents.setDiary(' '));
            this.state = next;
            this.persistDraft();
          },
          onBack: () => this.back(),
          onSend: (text: string) => this.sendMessage(text),
        })
      } else if (this.state.screen.name === 'diary') {
        DiaryScreen({
          draft: this.state.draft,
          controller: this.buildChatController(),
          onSave: (diary: string | undefined, enabled: boolean) => this.savePastEntry(diary, enabled),
          onBack: () => this.back(),
        })
      } else if (this.state.screen.name === 'timeline') {
        TimelineScreen({
          entries: this.entries,
          onOpen: (id: string) => this.openDetail(id),
          onBack: () => this.back(),
        })
      } else if (this.state.screen.name === 'detail') {
        DetailScreen({
          entry: this.detailEntry,
          onCard: (id: string) => {
            this.state = { screen: Screen.card(id), draft: this.state.draft };
            this.refreshEntryCaches();
          },
          onBack: () => this.back(),
          onRemove: (id: string) => {
            this.entryRepo.remove(id);
            this.state = transition(this.state, RecallEvents.back());
            this.refreshEntries();
            this.refreshEntryCaches();
          },
        })
      } else if (this.state.screen.name === 'card') {
        CardScreen({
          entry: this.cardEntry,
          onSelect: (template: StickerTemplateId) => {
            if (this.cardEntry !== undefined) {
              this.entryRepo.update(this.cardEntry.id, { stickerTemplate: template });
              this.refreshEntryCaches();
            }
          },
          onDone: () => this.back(),
          onHome: () => {
            this.state = transition(this.state, RecallEvents.reset());
            this.refreshEntryCaches();
          },
        })
      } else {
        Text('MILO')
          .fontSize(28)
          .fontColor('#ffffff')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#050608')
  }
}

class OfflineFetcher implements FetchLike {
  async fetch(_input: string, _init: Object): Promise<never> {
    throw new Error('offline');
  }
}

const offlineFetcher: FetchLike = new OfflineFetcher();
