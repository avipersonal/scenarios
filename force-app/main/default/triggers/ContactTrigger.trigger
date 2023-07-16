trigger ContactTrigger on Contact (after insert, before insert, before update, after update, after delete, after undelete) {
   new ContactTriggerHandler().run();
}