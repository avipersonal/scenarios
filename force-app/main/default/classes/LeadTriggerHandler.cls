public with sharing class LeadTriggerHandler extends TriggerHandler {
  List<Lead> leadListOld = new List<Lead>();
  List<Lead> leadListNew = new List<Lead>();
  Map<Id, Lead> leadOldMap = new Map<Id, Lead>();

  public LeadTriggerHandler() {
    this.leadListNew = (List<Lead>) Trigger.new;
    this.leadListOld = (List<Lead>) Trigger.old;
    this.leadOldMap = (Map<Id, Lead>) Trigger.oldMap;
  }

  protected override void afterUpdate() {
    createFollowUpTaskAndUpdateTaskDesOnLeadConversion(leadListNew, leadOldMap);
    updAccActiveFieldConLeadContactFieldOppDescFieldOnLeadConversion(
      leadListNew,
      leadOldMap
    );
  }

  private void updAccActiveFieldConLeadContactFieldOppDescFieldOnLeadConversion(
    List<Lead> leadListNew,
    Map<Id, Lead> leadOldMap
  ) {
    
    List<SObject> sobjectToUpd = new List<SObject>();
    Set<Id> accountIds = new Set<Id>();
    List<Account> accList = new List<Account>();
    Map<Id, String> accIdToLeadNameMap = new Map<Id, String>();
    boolean haveAccountIds;

    accountIds = getAccountIds(leadListNew, leadOldMap);
    haveAccountIds = accountIds.size() > 0;

    if (haveAccountIds) {
      accList = getAccountsAlongWithRelatedConAndOpps(accountIds);
      accIdToLeadNameMap = getAccIdToLeadNameMap(leadListNew, accountIds);
      sobjectToUpd = getConOppAccToUpd(accList, accIdToLeadNameMap);

      if (sobjectToUpd.size() > 0) {
        update sobjectToUpd;
      }
    }
  }

  private void createFollowUpTaskAndUpdateTaskDesOnLeadConversion(
    List<Lead> leadListNew,
    Map<Id, Lead> leadOldMap
  ) {
  
    Set<Id> accountIds = new Set<Id>();
    Map<Id, map<string, sobject>> accIdToMapOfsObjectNameToRecord = new Map<Id, map<string, sobject>>();
    List<Account> convertedAccList = new List<Account>();

    accountIds = getAccountIds(leadListNew, leadOldMap);

    boolean isAccountIdsAvalable = accountIds.size() > 0;

    if (isAccountIdsAvalable) {
      convertedAccList = getConvertedAccountsList(accountIds);

      boolean isConvertAccountsAvailable = convertedAccList.size() > 0;

      accIdToMapOfsObjectNameToRecord = structureDataOfAccConAndOppInMap(
        convertedAccList
      );

      boolean isaccMapHaveData = accIdToMapOfsObjectNameToRecord.size() > 0;

      if (isaccMapHaveData) {
        insertTaskWithDescription(accIdToMapOfsObjectNameToRecord);
      }
    }
  }

  private Set<Id> getAccountIds(
    List<Lead> leadListNew,
    Map<Id, Lead> leadOldMap
  ) {
    Set<Id> accountIds = new Set<Id>();

    for (Lead l : leadListNew) {
      if (Trigger.isInsert) {
        if (l.IsConverted == true) {
          accountIds.add(l.ConvertedAccountId);
        }
      }
      if (Trigger.isUpdate) {
        if (
          (l.isConverted == true) &&
          (l.IsConverted != leadOldMap.get(l.Id).IsConverted)
        ) {
          accountIds.add(l.ConvertedAccountId);
        }
      }
    }

    return accountIds;
  }

  private List<Account> getConvertedAccountsList(Set<Id> accIds) {
    return [
      SELECT
        Name,
        (SELECT LastName, Email, FirstName FROM Contacts),
        (SELECT CloseDate, StageName, Name, Amount FROM Opportunities)
      FROM Account
      WHERE Id IN :accIds
    ];
  }

  private Map<Id, map<string, sobject>> structureDataOfAccConAndOppInMap(
    List<Account> conAccList
  ) {
    Map<Id, map<string, sobject>> accIdToMapOfsObjectNameToRecord = new Map<Id, map<string, sobject>>();

    for (Account acc : conAccList) {
      List<Contact> conList = acc.Contacts;
      List<Opportunity> oppList = acc.Opportunities;
      Map<string, sobject> sobjectNametoRecMap = new Map<string, sobject>{
        'Account' => acc,
        'Contact' => conList[0]
      };
      if (oppList.size() > 0) {
        sobjectNametoRecMap.put('Opportunity', oppList[0]);
      }
      accIdToMapOfsObjectNameToRecord.put(acc.Id, sobjectNametoRecMap);
    }

    return accIdToMapOfsObjectNameToRecord;
  }

  private void insertTaskWithDescription(
    Map<Id, map<string, sobject>> accToConOppAccMap
  ) {
    List<Task> taskListToUpd = new List<Task>();

    for (Id accId : accToConOppAccMap.keySet()) {
      Map<string, sobject> objNameToRecordMap = accToConOppAccMap.get(accId);
      Opportunity opp = (Opportunity) objNameToRecordMap.get('Opportunity');
      Contact con = (Contact) objNameToRecordMap.get('Contact');
      Account acc = (Account) objNameToRecordMap.get('Account');

      Task t = new Task();
      t.Subject = 'Follow Up Task with Converted Leads';
      t.ActivityDate = Date.today();
      t.WhoId = con.Id;
      t.Priority = 'High';

      if (opp != null) {
        t.WhatId = opp.Id;
      }

      string conName = con.FirstName == null
        ? con.LastName
        : con.FirstName + ' ' + con.LastName;
      string des =
        'Account Name: ' +
        acc.Name +
        '\n' +
        'Contact Name: ' +
        conName +
        '\n' +
        'Contact Email: ' +
        con.Email +
        '\n' +
        'Opportunity Name: ' +
        (opp?.Name != null ? opp.Name : '') +
        '\n' +
        'Opportunity Close Date: ' +
        (opp?.CloseDate != null ? String.valueof(opp.CloseDate) : '') +
        '\n' +
        'Opportunity Stage: ' +
        (opp?.StageName != null ? opp.StageName : '') +
        '\n';

      t.Description = des;

      taskListToUpd.add(t);
    }

    if (taskListToUpd.size() > 0) {
      insert taskListToUpd;
    }
  }

  private Map<Id, string> getAccIdToLeadNameMap(
    List<Lead> leadListNew,
    Set<Id> accountIds
  ) {
    Map<Id, String> accIdToLeadNameMap = new Map<Id, String>();

    for (Lead le : leadListNew) {
      if (accountIds.contains(le.ConvertedAccountId)) {
        string name = le.FirstName != null
          ? le.FirstName + ' ' + le.LastName
          : le.LastName;
        accIdToLeadNameMap.put(le.ConvertedAccountId, name);
      }
    }

    return accIdToLeadNameMap;
  }

  private list<Account> getAccountsAlongWithRelatedConAndOpps(Set<Id> accIds) {
    List<Account> accList = new List<Account>();
    try {
      accList = [
        SELECT
          (SELECT Lead_Contact__c FROM Contacts),
          (SELECT Description FROM Opportunities),
          Active__c
        FROM Account
        WHERE Id IN :accIds
      ];
    } catch (QueryException e) {
      return accList;
    }
    return accList;
  }

  private List<sobject> getConOppAccToUpd(
    List<Account> accList,
    Map<Id, string> accIdToLeadNameMap
  ) {
    List<SObject> sobjectsToUpd = new List<SObject>();

    for (Account acc : accList) {
      List<Opportunity> oppList = acc.Opportunities;
      System.debug('Opp List -> ' + oppList);

      List<Contact> conList = acc.Contacts;

      acc.Active__c = 'Yes';
      sobjectsToUpd.add(acc);
      conList[0].lead_Contact__c = true;
      sobjectsToUpd.add(conList[0]);

      if (oppList.size() > 0 && accIdToLeadNameMap.containsKey(acc.Id)) {
        oppList[0].Description = accIdToLeadNameMap.get(acc.id);
        sobjectsToUpd.add(oppList[0]);
      }
    }

    System.debug(
      'Sobjects To Update -> ' + JSON.serializePretty(sobjectsToUpd)
    );
    return sobjectsToUpd;
  }
}
