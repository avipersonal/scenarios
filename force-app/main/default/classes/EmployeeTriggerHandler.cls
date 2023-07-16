public with sharing class EmployeeTriggerHandler extends TriggerHandler {
    
    list<Employee__c> empListNew;
    list<Employee__c> empListOld;
    map<Id, Employee__c> empOldMap;

    public EmployeeTriggerHandler() {
       empListNew = (list<Employee__c>) Trigger.New;
       empListOld = (list<Employee__c>) Trigger.old;
       empOldMap = (map<Id, Employee__c>) Trigger.oldMap;
    }

    public override void afterInsert() {
       updateMaxMinSalOnTechFirm(empListNew);
    }

    public override void afterUpdate() {
        updateMaxMinSalOnTechFirm(empListNew);
    }

    public override void afterDelete() {
        updateMaxMinSalOnTechFirm(empListOld);
    }

    public override void afterUndelete() {
        updateMaxMinSalOnTechFirm(empListNew);
    }

    public void updateMaxMinSalOnTechFirm(list<Employee__c> empList) {
        Id techFirmOldId;
        Set<Id> tfFirmsUsed = new Set<Id>();
        list<Tech_Firm__c> tfFirmsColl = new list<Tech_Firm__c>();
        Set<Id> techFirmIds = new Set<Id>();
        for(Employee__c emps : empList) {
            if(Trigger.isInsert) {
                if(emps.Tech_Firm__c != null) {
                    techFirmIds.add(emps.Tech_Firm__c);
                }
            }
            if(Trigger.isUpdate) {
                techFirmOldId = empOldMap.get(emps.Id).Tech_Firm__c;
                if(emps.Tech_Firm__c != techFirmOldId) {
                    techFirmIds.add(emps.Tech_Firm__c);
                    techFirmIds.add(techFirmOldId);
                } else if(emps.Salary__c != empOldMap.get(emps.Id).Salary__c) {
                    techFirmIds.add(emps.Tech_Firm__c);
                }
            }
            if(Trigger.isDelete) {
               if(emps.Tech_Firm__c != null) {
                  techFirmIds.add(emps.Tech_Firm__c);
               }
            }
            if(Trigger.isUndelete) {
                if(emps.Tech_Firm__c != null) {
                    techFirmIds.add(emps.Tech_Firm__c);
                }
            }
        }
        if(techFirmIds.size() > 0) {
            list<AggregateResult> results = [Select MIN(Salary__c) minSalary, MAX(Salary__c) maxSalary, Tech_Firm__c from Employee__c where Tech_Firm__c IN :techFirmIds Group by Tech_Firm__c];
            if(results.size() > 0) {
                for(AggregateResult result : results) {
                    Tech_Firm__c tfFirm = new Tech_Firm__c(Id= (Id) result.get('Tech_Firm__c'));
                    tfFirm.Minimum_Salary__c = (double) result.get('minSalary');
                    tfFirm.Maximum_Salary__c = (double) result.get('maxSalary');
                    tfFirmsColl.add(tfFirm);
                    tfFirmsUsed.add((Id) result.get('Tech_Firm__c'));
                }
                for(Id techFirmId : techFirmIds) {
                    if(!tfFirmsUsed.contains(techFirmId)) {
                       Tech_Firm__c tfFirm = new Tech_Firm__c(Id=techFirmId);
                       tfFirm.Minimum_Salary__c = 0;
                       tfFirm.Maximum_Salary__c = 0;
                       tfFirmsColl.add(tfFirm);
                    }
                }
            } else {
                for(Id techFirmId : techFirmIds) {
                    Tech_Firm__c tfFirm = new Tech_Firm__c(Id=techFirmId);
                    tfFirm.Minimum_Salary__c = 0;
                    tfFirm.Maximum_Salary__c = 0;
                    tfFirmsColl.add(tfFirm);
                }
            }
            if(tfFirmsColl.size() > 0) {
                update tfFirmsColl;
            }
        }
    } 
}