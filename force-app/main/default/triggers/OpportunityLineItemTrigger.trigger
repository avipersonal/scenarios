trigger OpportunityLineItemTrigger on OpportunityLineItem (after insert, after update, after undelete, after delete) {
     new OpportunityLineItemTriggerHandler().run();
}