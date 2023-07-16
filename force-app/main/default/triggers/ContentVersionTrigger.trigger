trigger ContentVersionTrigger on ContentVersion (after insert) {
    new ContentVersionTriggerHandler().run();
}