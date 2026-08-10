import localUnitTest from './LocalUnit.test';
import domainTest from '../ohosTest/ets/test/Domain.test';
import recallMachineTest from '../ohosTest/ets/test/RecallMachine.test';

export default function testsuite() {
  localUnitTest();
  domainTest();
  recallMachineTest();
}
