trigger AccountTrigger on Account (after insert, after update, before insert, before update) {
   new AccountTriggerHandler().run();
}