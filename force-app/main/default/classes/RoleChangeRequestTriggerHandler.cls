public with sharing class RoleChangeRequestTriggerHandler extends TriggerHandler {
    list<Role_Change_Request__c> roleChangeRequestNewList;
    list<Role_Change_Request__c> roleChangeRequestOldList;
    map<Id, Role_Change_Request__c> roleChangeRequestOldMap;

    public RoleChangeRequestTriggerHandler(){
        roleChangeRequestNewList = (List<Role_Change_Request__c>) Trigger.New;
        roleChangeRequestOldList = (List<Role_Change_Request__c>) Trigger.Old;
        roleChangeRequestOldMap = (map<Id, Role_Change_Request__c>) Trigger.OldMap;
    }

    protected override void beforeInsert(){
        updateUserRoleWithNewRole(roleChangeRequestNewList);
    }

    protected override void beforeUpdate(){
        updateUserRoleWithNewRole(roleChangeRequestNewList);
    }

    private void updateUserRoleWithNewRole(List<Role_Change_Request__c> roleChangeRequestNewList) {


        list<RoleChange__e> roleChangeEventList = new list<RoleChange__e>();

        for(Role_Change_Request__c roleChgReq : roleChangeRequestNewList){
            if(Trigger.isInsert){
                if(roleChgReq.Status__c == 'Approved'){
                    roleChangeEventList.add(new RoleChange__e(RoleId__c=roleChgReq.New_Role__c, UserId__c=roleChgReq.User__c));
                }
            }
            if(Trigger.isUpdate){
                if(roleChgReq.Status__c == 'Approved' && (roleChgReq.Status__c != roleChangeRequestOldMap.get(roleChgReq.Id).Status__c)){
                    roleChangeEventList.add(new RoleChange__e(RoleId__c=roleChgReq.New_Role__c, UserId__c=roleChgReq.User__c));
                }
            }
        }
        if(roleChangeEventList.size() > 0){
            EventBus.publish(roleChangeEventList);
        }

    }
    
}