public with sharing class OpportunityTriggerHandler extends TriggerHandler {
  list<Opportunity> oppListOld;
  list<Opportunity> oppListNew;
  map<Id, Opportunity> oppIdOldMap;
  boolean isInsertContext = Trigger.isInsert;
  boolean isUpdateContext = Trigger.isUpdate;
  boolean isDeleteContext = Trigger.isDelete;
  boolean isUndeleteContext = Trigger.isUndelete;

  public OpportunityTriggerHandler() {
    oppListNew = Trigger.New;
    oppListOld = Trigger.Old;
    oppIdOldMap = (map<Id, Opportunity>) Trigger.oldMap; 
  }

  protected override void afterInsert() {
    updateAnnualRevenueBasedOnRelOpp(oppListNew, oppIdOldMap);
    updateParentAccountWithOppNameOfHighAmount(oppListNew, oppIdOldMap);
    updateAccRatingBasedOnRelatedOppAmount(oppListNew, oppIdOldMap);
    createOrUpdTaskWithDescriptionOfOppStageName(oppListNew, oppIdOldMap);
    updateAccountStatusBasedOnOppStageName(oppListNew, oppIdOldMap);
  }

  protected override void afterUpdate() {
    updateAnnualRevenueBasedOnRelOpp(oppListNew, oppIdOldMap);
    updateParentAccountWithOppNameOfHighAmount(oppListNew, oppIdOldMap);
    updateAccRatingBasedOnRelatedOppAmount(oppListNew, oppIdOldMap);
    createOrUpdTaskWithDescriptionOfOppStageName(oppListNew, oppIdOldMap);
    updateAccountStatusBasedOnOppStageName(oppListNew, oppIdOldMap);
  }

  protected override void afterDelete() {
    updateAnnualRevenueBasedOnRelOpp(oppListOld, oppIdOldMap);
    updateParentAccountWithOppNameOfHighAmount(oppListOld, oppIdOldMap);
    updateAccRatingBasedOnRelatedOppAmount(oppListOld, oppIdOldMap);
    updateAccountStatusBasedOnOppStageName(oppListOld, oppIdOldMap);
  }

  protected override void afterUndelete() {
    updateAnnualRevenueBasedOnRelOpp(oppListNew, oppIdOldMap);
    updateParentAccountWithOppNameOfHighAmount(oppListNew, oppIdOldMap);
    updateAccRatingBasedOnRelatedOppAmount(oppListNew, oppIdOldMap);
    updateAccountStatusBasedOnOppStageName(oppListNew, oppIdOldMap);
  }

  private void updateAnnualRevenueBasedOnRelOpp(
    List<Opportunity> oppListNew,
    Map<Id, Opportunity> oppIdOldMap
  ) {
    Set<Id> accIds = getAccountIds(oppListNew, oppIdOldMap, 'Amount');
    Map<Id, decimal> accIdToValueMap = new Map<Id, decimal>();
    List<Account> accToUpdate = new List<Account>();

    List<AggregateResult> aggResult = [
      SELECT SUM(Amount), AccountId
      FROM Opportunity
      WHERE AccountId IN :accIds
      GROUP BY AccountId
    ];
    for (AggregateResult agg : aggResult) {
      accIdToValueMap.put(
        (Id) agg.get('AccountId'),
        (decimal) agg.get('expr0')
      );
    }

    for (Id accId : accIds) {
      Account acc = new Account(Id = accId);
      if (accIdToValueMap.containskey(accId)) {
        acc.AnnualRevenue = accIdToValueMap.get(accId);
      } else {
        acc.AnnualRevenue = 0;
      }
      accToUpdate.add(acc);
    }

    if (accToUpdate.size() > 0) {
      update accToUpdate;
    }
  }

  private void updateAccRatingBasedOnRelatedOppAmount(
    List<Opportunity> oppList,
    Map<Id, Opportunity> oppIdOldMap
  ) {

    Set<Id> accIds = new Set<Id>();
    Map<Id, Decimal> accIdToOppAmountMap = new Map<Id, Decimal>();
    List<Account> accListToUpd = new List<Account>();

    accIds = getAccountIds(oppList, oppIdOldMap, 'Amount');
    accIdToOppAmountMap = createMapOfAccIdAndOppSumAmountMap(accIds);
    accListToUpd = createAccountListToUpdate(accIdToOppAmountMap, accIds);

    boolean isAccountListFilled = accListToUpd.size() > 0;

    if (isAccountListFilled) {
      update accListToUpd;
    }
  }

  private void updateAccountStatusBasedOnOppStageName(
    list<Opportunity> oppList,
    map<Id, Opportunity> oppMapOld
  ) {
    Set<Id> accIds = new Set<Id>();
    Map<Id, double> accIdToTotalOppMap = new Map<Id, double>();
    Map<Id, double> accIdToClosedWonOppMap = new Map<Id, double>();
    List<Account> accListToUpd = new List<Account>();

    accIds = getAccountIds(oppList, oppMapOld, 'StageName');
    accIdToTotalOppMap = createMapOfAccIdAndTotalOppCount(accIds);
    accIdToClosedWonOppMap = createMapOfAccIdAndClosedWonOppCount(accIds);
    accListToUpd = getAccListToUpd(
      accIds,
      accIdToTotalOppMap,
      accIdToClosedWonOppMap
    );

    boolean isAccountListFilled = accListToUpd.size() > 0;

    if (isAccountListFilled) {
      update accListToUpd;
    }
  }

  private void updateSumOfOpportunitiesOnRelatedAccount(
    list<Opportunity> oppList,
    map<Id, Opportunity> oppIdOldMap
  ) {
    map<Id, double> accountIdTotalOppAmountMap = new Map<Id, double>();
    list<Account> accListToUpd = new List<Account>();
    set<Id> accountIds = new Set<Id>();

    for (Opportunity opp : oppList) {
      if (Trigger.isInsert) {
        if (opp.AccountId != null) {
        }
      }
    }
  }

  private void updateParentAccountWithOppNameOfHighAmount(
    list<Opportunity> oppList,
    Map<Id, Opportunity> oppOldMap
  ) {
  
    Set<Id> accountIds = getAccountIds(oppList, oppOldMap);

    Map<Id, string> accIdToOppNameMap = createAccIdToOppNameMap(accountIds);

    List<Account> accListToUpd = prepareAccountListToUpd(accIdToOppNameMap);

    if (accListToUpd.size() > 0) {
      update accListToUpd;
    }
  }

  private Set<Id> getAccountIds(
    List<Opportunity> oppList,
    Map<Id, Opportunity> oppOldMap
  ) {
    Set<Id> accountIds = new Set<Id>();

    for (Opportunity opp : oppList) {
      if (Trigger.isInsert || Trigger.isUndelete || Trigger.isDelete) {
        if (opp.AccountId != null) {
          accountIds.add(opp.AccountId);
        }
      } else if (Trigger.isUpdate) {
        if (
          opp.AccountId != null &&
          opp.Amount != oppOldMap.get(opp.Id).Amount
        ) {
          accountIds.add(opp.AccountId);
        }
        if (opp.AccountId != oppOldMap.get(opp.Id).AccountId) {
          if (opp.AccountId != null) {
            accountIds.add(opp.AccountId);
          }
          if (oppOldMap.get(opp.Id).AccountId != null) {
            accountIds.add(oppOldMap.get(opp.Id).AccountId);
          }
        }
      }
    }

    return accountIds;
  }

  private Map<Id, string> createAccIdToOppNameMap(Set<Id> accountIds) {
    Map<Id, decimal> accIdToMaxOppMap = new Map<Id, decimal>();
    Map<Id, string> accIdToOppNameMap = new Map<Id, string>();

    List<Opportunity> oppList = [
      SELECT Amount, Name, AccountId
      FROM Opportunity
      WHERE AccountId IN :accountIds
    ];

    for (Opportunity opp : oppList) {
      if (
        accIdToOppNameMap.containskey(opp.AccountId) &&
        accIdToMaxOppMap.containskey(opp.AccountId)
      ) {
        decimal oppAmOld = (decimal) accIdToMaxOppMap.get(opp.AccountId);
        if (opp.Amount > oppAmOld) {
          accIdToMaxOppMap.put(opp.AccountId, opp.Amount);
          accIdToOppNameMap.put(opp.AccountId, opp.Name);
        }
      } else if (opp.Amount != null) {
        accIdToOppNameMap.put(opp.AccountId, opp.Name);
        accIdToMaxOppMap.put(opp.AccountId, opp.Amount);
      }
    }

    for (Id accId : accountIds) {
      if (!accIdToOppNameMap.containsKey(accId)) {
        accIdToOppNameMap.put(accId, '');
      }
    }

    return accIdToOppNameMap;
  }

  private List<Account> prepareAccountListToUpd(
    Map<Id, string> accIdToOppNameMap
  ) {
    List<Account> accListToUpd = new List<Account>();

    for (Id accId : accIdToOppNameMap.Keyset()) {
      if (accIdToOppNameMap.containskey(accId)) {
        Account acc = new Account(Id = accId);
        acc.maxOpp__c = accIdToOppNameMap.get(accId);
        accListToUpd.add(acc);
      }
    }

    return accListToUpd;
  }

  private void createOrUpdTaskWithDescriptionOfOppStageName(
    list<Opportunity> oppNewList,
    map<Id, Opportunity> oppOldMap
  ) {
    Set<Id> oppIds = new Set<Id>();
    list<Task> taskList = new List<Task>();
    map<Id, list<Task>> oppIdListOfTasksMap = new Map<Id, list<Task>>();
    list<Task> taskToDml = new List<Task>();

    oppIds = getOpportunityIds(oppNewList, oppOldMap);
    taskList = getTasksRelatedToOpp(oppIds);
    oppIdListOfTasksMap = createMapOfOppIdAndListOfTasks(taskList);
    taskToDml = getTaskListForUpsert(oppIds, oppNewList, oppIdListOfTasksMap);

    boolean isTaskToDmlFilled = taskToDml.size() > 0;

    if (isTaskToDmlFilled) {
      upsert taskToDml;
    }
  }

  private Set<Id> getOpportunityIds(
    list<Opportunity> oppNewList,
    map<Id, Opportunity> oppIdOldMap
  ) {
    Set<Id> oppIds = new Set<Id>();
    boolean isInsertContext = Trigger.isInsert;
    boolean isUpdateContext = Trigger.isUpdate;

    for (Opportunity opp : oppNewList) {
      if (isInsertContext) {
        if (opp.StageName != null) {
          oppIds.add(opp.Id);
        }
      }
      if (isUpdateContext) {
        boolean isOppHaveStageName = opp.StageName != null;
        boolean isOppStageNameChanged =
          opp.StageName != oppIdOldMap.get(opp.Id).StageName;

        if (isOppHaveStageName && isOppStageNameChanged) {
          oppIds.add(opp.Id);
        }
      }
    }

    return oppIds;
  }

  private list<Task> getTasksRelatedToOpp(Set<Id> oppIds) {
    return [SELECT WhatId, Description FROM Task WHERE WhatId IN :oppIds];
  }

  private map<Id, list<Task>> createMapOfOppIdAndListOfTasks(
    list<Task> taskList
  ) {
    map<Id, list<Task>> oppIdListOfTasksMap = new Map<Id, list<Task>>();

    for (Task t : taskList) {
      if (oppIdListOfTasksMap.containsKey(t.WhatId)) {
        oppIdListOfTasksMap.get(t.WhatId).add(t);
      } else {
        oppIdListOfTasksMap.put(t.WhatId, new List<Task>{ t });
      }
    }

    return oppIdListOfTasksMap;
  }

  private list<Task> getTaskListForUpsert(
    Set<Id> oppIds,
    list<Opportunity> oppNewList,
    map<Id, list<Task>> oppIdListOfTasksMap
  ) {
    list<Task> taskToDml = new List<Task>();

    for (Opportunity opp : oppNewList) {
      if (oppIdListOfTasksMap.containsKey(opp.Id)) {
        for (Task t : oppIdListOfTasksMap.get(opp.Id)) {
          t.Description = opp.StageName;
          taskToDml.add(t);
        }
      } else {
        if (oppIds.contains(opp.Id)) {
          Task t = new task(
            WhatId = opp.Id,
            Subject = 'Other',
            Description = opp.StageName
          );
          taskToDml.add(t);
        }
      }
    }

    return taskToDml;
  }

  private Set<Id> getAccountIds(
    list<Opportunity> oppList,
    map<Id, Opportunity> oppListOld,
    string fieldApiName
  ) {
    Set<Id> accIds = new Set<Id>();

    for (Opportunity opp : oppList) {
      if (
        this.isInsertContext ||
        this.isDeleteContext ||
        this.isUndeleteContext
      ) {
        if (opp.AccountId != null) {
          accIds.add(opp.AccountId);
        }
      }

      if (this.isUpdateContext) {
        string accIdForOppOld = oppListOld.get(opp.Id).AccountId;
        if (
          (opp.get(fieldApiName) != oppListOld.get(opp.Id).get(fieldApiName))
        ) {
          accIds.add(opp.AccountId);
        }
        if (opp.AccountId != accIdForOppOld) {
          if (accIdForOppOld != null) {
            accIds.add(accIdForOppOld);
          }
          if (opp.AccountId != null) {
            accIds.add(opp.AccountId);
          }
        }
      }
    }

    return accIds;
  }

  private Map<Id, double> createMapOfAccIdAndTotalOppCount(Set<Id> accIds) {
    Map<Id, double> accIdToTotalOppMap = new Map<Id, double>();

    list<AggregateResult> totalOppResult = [
      SELECT COUNT(Id), AccountId
      FROM Opportunity
      WHERE AccountId IN :accIds
      GROUP BY AccountId
    ];

    for (AggregateResult r : totalOppResult) {
      accIdToTotalOppMap.put((Id) r.get('AccountId'), (Double) r.get('expr0'));
    }

    return accIdToTotalOppMap;
  }

  private Map<Id, double> createMapOfAccIdAndClosedWonOppCount(Set<Id> accIds) {
    Map<Id, double> accIdToClosedWonOppMap = new Map<Id, double>();

    list<AggregateResult> totalOppResult = [
      SELECT COUNT(Id), AccountId
      FROM Opportunity
      WHERE AccountId IN :accIds AND StageName = 'Closed Won'
      GROUP BY AccountId
    ];

    for (AggregateResult r : totalOppResult) {
      accIdToClosedWonOppMap.put(
        (Id) r.get('AccountId'),
        (Double) r.get('expr0')
      );
    }

    return accIdToClosedWonOppMap;
  }

  private list<Account> getAccListToUpd(
    Set<Id> accIds,
    Map<Id, double> accIdToTotalOppMap,
    Map<Id, double> accIdToClosedWonOppMap
  ) {
    list<Account> accListToUpd = new List<Account>();

    for (Id accId : accIds) {
      Account acc = new Account(Id = accId);
      if (
        accIdToTotalOppMap.containsKey(accId) ||
        accIdToClosedWonOppMap.containsKey(accId)
      ) {
        double tOpCount = accIdToTotalOppMap.get(accId);
        double tCwCount = accIdToClosedWonOppMap.get(accId);

        if (tOpCount == tCwCount) {
          acc.Account_Status__c = 'Closed';
        } else {
          acc.Account_Status__c = 'Open';
        }
      } else {
        acc.Account_Status__c = 'No Opportunity';
      }
      accListToUpd.add(acc);
    }

    return accListToUpd;
  }

  private map<Id, Decimal> createMapOfAccIdAndOppSumAmountMap(Set<Id> accIds) {
    Map<Id, Decimal> accIdToOppSumAmountMap = new Map<Id, Decimal>();

    list<AggregateResult> aggResults = [
      SELECT SUM(Amount), AccountId
      FROM Opportunity
      WHERE AccountId IN :accIds
      GROUP BY AccountId
    ];

    for (AggregateResult r : aggResults) {
      accIdToOppSumAmountMap.put(
        (Id) r.get('AccountId'),
        (Decimal) r.get('expr0')
      );
    }

    return accIdToOppSumAmountMap;
  }

  private list<Account> createAccountListToUpdate(
    Map<Id, Decimal> accIdToOppSumAmountMap,
    Set<Id> accIds
  ) {
    List<Account> accListToUpd = new List<Account>();

    for (Id accId : accIds) {
      Account acc = new Account(Id = accId);
      getAndSetAccRating(accIdToOppSumAmountMap, acc);
      accListToUpd.add(acc);
    }

    return accListToUpd;
  }

  private void getAndSetAccRating(
    Map<Id, Decimal> accIdToOppSumAmountMap,
    Account acc
  ) {
    if (accIdToOppSumAmountMap.containsKey(acc.Id)) {
      decimal amountSum = accIdToOppSumAmountMap.get(acc.Id);
      if (amountSum <= 50000) {
        acc.Rating = 'Cold';
      } else if (amountSum <= 100000) {
        acc.Rating = 'Warm';
      } else {
        acc.Rating = 'Hot';
      }
    } else {
      acc.Rating = 'Cold';
    }
  }
}


