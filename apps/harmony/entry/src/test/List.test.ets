import localUnitTest from './LocalUnit.test';
import domainTest from '../ohosTest/ets/test/Domain.test';
import recallMachineTest from '../ohosTest/ets/test/RecallMachine.test';
import moodAssetsTest from '../ohosTest/ets/test/MoodAssets.test';
import entryRepositoryTest from '../ohosTest/ets/test/EntryRepository.test';
import offlineFlowTest from '../ohosTest/ets/test/OfflineFlow.test';
import moodSwipeModelTest from '../ohosTest/ets/test/MoodSwipeModel.test';
import conversationControllerTest from '../ohosTest/ets/test/ConversationController.test';
import systemAdaptersTest from '../ohosTest/ets/test/SystemAdapters.test';
import cardRendererTest from '../ohosTest/ets/test/CardRenderer.test';

export default function testsuite() {
  localUnitTest();
  domainTest();
  recallMachineTest();
  moodAssetsTest();
  entryRepositoryTest();
  offlineFlowTest();
  moodSwipeModelTest();
  conversationControllerTest();
  systemAdaptersTest();
  cardRendererTest();
}