trigger EmployeeTrigger on Employee__c (after insert, after update, after delete, after undelete) {
    new EmployeeTriggerHandler().run();
}