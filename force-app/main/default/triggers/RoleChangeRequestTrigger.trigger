trigger RoleChangeRequestTrigger on Role_Change_Request__c (before insert, before update) {
   new RoleChangeRequestTriggerHandler().run();
}