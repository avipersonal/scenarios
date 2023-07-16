trigger TaskTrigger on Task(after insert, after update) {
  new TaskTriggerHandler().run();
}
