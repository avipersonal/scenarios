trigger OpportunityTrigger on Opportunity (after insert, after update, after delete, after undelete) {
   new OpportunityTriggerHandler().run();
}