import localUnitTest from './LocalUnit.test';
import domainTest from '../ohosTest/ets/test/Domain.test';
import recallMachineTest from '../ohosTest/ets/test/RecallMachine.test';
import moodAssetsTest from '../ohosTest/ets/test/MoodAssets.test';
import entryRepositoryTest from '../ohosTest/ets/test/EntryRepository.test';

export default function testsuite() {
  localUnitTest();
  domainTest();
  recallMachineTest();
  moodAssetsTest();
  entryRepositoryTest();
}