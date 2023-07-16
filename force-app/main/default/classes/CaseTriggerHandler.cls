public with sharing class CaseTriggerHandler extends TriggerHandler {
  private list<Case> caseList;
  private list<Case> caseListOld;
  private map<Id, case> caseMap;
  private boolean isInsertContext = Trigger.isInsert;
  private boolean isUpdateContext = Trigger.isUpdate;
  private boolean isDeleteContext = Trigger.isDelete;
  private boolean isUndeleteContext = Trigger.isUndelete;

  public CaseTriggerHandler() {
    this.caseList = (list<Case>) Trigger.new;
    this.caseMap = (map<Id, case>) Trigger.oldMap;
    this.caseListOld = (list<Case>) Trigger.old;
  }

  public override void afterInsert() {
    updateLatestCaseOnAccCusField(caseList);
    updateAccDesAndTaskStatusBasedOnCaseStatus(caseList, caseMap);
    updateAccCasesCusFieldBasedOnCasesStatus(caseList, caseMap);
    updateAccRatingBasedOnNumberOfClosedCases(caseList, caseMap);
  }

  public override void afterUpdate() {
    updateLatestCaseOnAccCusField(caseList);
    updateAccDesAndTaskStatusBasedOnCaseStatus(caseList, caseMap);
    updateAccRatingBasedOnNumberOfClosedCases(caseList, caseMap);
    updateAccCasesCusFieldBasedOnCasesStatus(caseList, caseMap);
  }

  public override void afterDelete() {
    updateLatestCaseOnAccCusField(caseListOld);
    updateAccRatingBasedOnNumberOfClosedCases(caseListOld, caseMap);
    updateAccCasesCusFieldBasedOnCasesStatus(caseListOld, caseMap);
  }

  public override void afterUndelete() {
    updateLatestCaseOnAccCusField(caseList);
    updateAccRatingBasedOnNumberOfClosedCases(caseList, caseMap);
    updateAccCasesCusFieldBasedOnCasesStatus(caseList, caseMap);
  }

  private void updateAccRatingBasedOnNumberOfClosedCases(
    List<Case> caseList,
    Map<Id, Case> caseMapOld
  ) {
    List<Account> accListToUpd = new List<Account>();
    Set<Id> accIds = new Set<Id>();
    Map<Id, string> accIdToAccRatingValueMap = new Map<Id, string>();

    accIds = getAccountIds(caseList, caseMapOld, 'IsClosed');

    if (accIds.size() > 0) {
      List<AggregateResult> result = [
        SELECT COUNT(Id), AccountId
        FROM Case
        WHERE Status = 'Closed' AND AccountId IN :accIds
        GROUP BY AccountId
      ];

      if (result.size() > 0) {
        accListToUpd = prepareListOfAccountWithStatusToUpd(result, accIds);

        if (accListToUpd.size() > 0) {
          update accListToUpd;
        }
      }
    }
  }

  private void updateAccCasesCusFieldBasedOnCasesStatus(
    List<Case> caseListTr,
    Map<Id, Case> caseMapOld
  ) {
    Set<Id> accIds = new Set<Id>();
    List<string> statusList = new List<string>{ 'New', 'Working', 'Escalated' };
    Map<Id, map<string, integer>> accIdToCaseStatusCountMap = new Map<Id, map<string, integer>>();
    List<Account> accListToUpd = new List<Account>();

    accIds = getAccountIds(caseListTr, caseMapOld, 'status');

    boolean isAccountIdsAvailable = accIds.size() > 0;

    if (isAccountIdsAvailable) {
      List<Case> caseList = [
        SELECT AccountId, Status
        FROM Case
        WHERE AccountId IN :accIds AND Status IN :statusList
      ];

      boolean isCaseListFilled = caseList.size() > 0;

      if (isCaseListFilled) {
        accIdToCaseStatusCountMap = createMapOfAccountIdToCaseStatusCountMap(
          caseList
        );

        accListToUpd = prepareAccountsForUpdate(
          accIds,
          accIdToCaseStatusCountMap
        );

        Boolean isAccListForUpdFilled = accListToUpd.size() > 0;

        if (isAccListForUpdFilled) {
          update accListToUpd;
        }
      }
    }
  }

  private void updateLatestCaseOnAccCusField(list<Case> caseList) {
    Set<Id> accIds = new Set<Id>();
    map<Id, string> accIdToLatestCaseMap = new Map<Id, string>();
    list<Account> accListToUpd = new List<Account>();

    for (Case c : caseList) {
      if (Trigger.isInsert) {
        if (c.AccountId != null) {
          accIds.add(c.AccountId);
        }
      }
      if (Trigger.isUpdate) {
        string caseOldAccId = caseMap.get(c.Id).AccountId;
        if (c.AccountId != caseOldAccId) {
          if (c.AccountId != null) {
            accIds.add(c.AccountId);
          }
          if (caseOldAccId != null) {
            accIds.add(caseOldAccId);
          }
        }
      }
      if (Trigger.isDelete) {
        if (c.AccountId != null) {
          accIds.add(c.AccountId);
        }
      }
      if (Trigger.isUndelete) {
        if (c.AccountId != null) {
          accIds.add(c.AccountId);
        }
      }
    }

    if (accIds.size() > 0) {
      list<AggregateResult> result = [
        SELECT COUNT(Id), MAX(CaseNumber), AccountId
        FROM Case
        WHERE AccountId IN :accIds
        GROUP BY AccountId
      ];

      if (result.size() > 0) {
        for (AggregateResult r : result) {
          Id accId = (Id) r.get('AccountId');
          accIdToLatestCaseMap.put(accId, (string) r.get('expr1'));
        }
      }

      system.debug('Account Ids ' + accIds);
      for (Id accId : accIds) {
        Account acc = new Account();
        if (accIdToLatestCaseMap.containsKey(accId)) {
          acc.Id = accId;
          acc.Latest_Case__c = accIdToLatestCaseMap.get(accId);
        } else {
          acc.Id = accId;
          acc.Latest_Case__c = null;
        }
        accListToUpd.add(acc);
      }

      system.debug('Accont List To Update ' + accListToUpd);
      if (accListToUpd.size() > 0) {
        update accListToUpd;
      }
    }
  }

  private Set<Id> getAccountIds(
    List<Case> caseList,
    Map<Id, Case> caseMapOld,
    string fieldName
  ) {
    Set<id> accIds = new Set<id>();

    for (Case c : caseList) {
      if (isInsertContext) {
        if (c.AccountId != null) {
          accIds.add(c.AccountId);
        }
      } else if (isUpdateContext) {
        if (
          c.AccountId != null &&
          (c.get(fieldName) != caseMapOld.get(c.Id).get(fieldName))
        ) {
          accIds.add(c.AccountId);
        }
        if (c.AccountId != caseMapOld.get(c.Id).AccountId) {
          if (c.AccountId != null) {
            accIds.add(c.AccountId);
          }
          if (caseMapOld.get(c.Id).AccountId != null) {
            accIds.add(caseMapOld.get(c.Id).AccountId);
          }
        }
      } else if (isDeleteContext) {
        if (c.AccountId != null) {
          accIds.add(c.AccountId);
        }
      } else if (isUndeleteContext) {
        if (c.AccountId != null) {
          accIds.add(c.AccountId);
        }
      }
    }

    return accIds;
  }

  private Map<Id, map<string, integer>> createMapOfAccountIdToCaseStatusCountMap(
    List<Case> caseList
  ) {
    Map<Id, map<string, integer>> accIdToCaseStatusCountMap = new Map<Id, map<string, integer>>();

    for (Case c : caseList) {
      if (accIdToCaseStatusCountMap.containsKey(c.AccountId)) {
        map<string, integer> temMap = accIdToCaseStatusCountMap.get(
          c.AccountId
        );
        if (temMap.containsKey(c.Status)) {
          integer value = temMap.get(c.Status);
          value += 1;
          temMap.put(c.Status, value);
        } else {
          temMap.put(c.Status, 1);
        }
      } else {
        map<string, integer> m = new Map<string, integer>();
        m.put(c.Status, 1);
        accIdToCaseStatusCountMap.put(c.AccountId, m);
      }
    }

    return accIdToCaseStatusCountMap;
  }

  private list<Account> prepareAccountsForUpdate(
    Set<Id> accIds,
    Map<Id, map<string, integer>> accIdToCaStatusCountMap
  ) {
    List<Account> accListToUpd = new List<Account>();

    for (Id accId : accIds) {
      Account ac = new Account(Id = accId);
      if (accIdToCaStatusCountMap.containsKey(accId)) {
        Map<string, integer> temMap = accIdToCaStatusCountMap.get(accId);
        if (temMap.containsKey('New')) {
          ac.Total_New_Cases__c = temMap.get('New');
        } else {
          ac.Total_New_Cases__c = 0;
        }
        if (temMap.containsKey('Working')) {
          ac.Total_Working_Cases__c = temMap.get('Working');
        } else {
          ac.Total_Working_Cases__c = 0;
        }
        if (temMap.containsKey('Escalated')) {
          ac.Total_Escalated_Cases__c = temMap.get('Escalated');
        } else {
          ac.Total_Escalated_Cases__c = 0;
        }
        accListToUpd.add(ac);
      }
    }

    return accListToUpd;
  }

  private List<Account> prepareListOfAccountWithStatusToUpd(
    List<AggregateResult> result,
    Set<Id> accIds
  ) {
    Map<Id, string> accIdToAccRatingValueMap = new Map<Id, string>();
    List<Account> accListToUpd = new List<Account>();

    accIdToAccRatingValueMap = prepareMapOfAccIdWithAccPriority(result, accIds);

    accListToUpd = prepareAccountListToUpd(accIdToAccRatingValueMap, accIds);

    return accListToUpd;
  }

  private Map<Id, string> prepareMapOfAccIdWithAccPriority(
    List<AggregateResult> result,
    Set<Id> accIds
  ) {
    Map<Id, string> accIdToAccRatingValueMap = new Map<Id, string>();

    for (AggregateResult r : result) {
      string rating = getRatingBasedOnCaseClosedCount((integer) r.get('expr0'));
      accIdToAccRatingValueMap.put((Id) r.get('AccountId'), rating);
    }

    for (Id acId : accIds) {
      if (!accIdToAccRatingValueMap.containsKey(acId)) {
        accIdToAccRatingValueMap.put(acId, 'Cold');
      }
    }

    return accIdToAccRatingValueMap;
  }

  private List<Account> prepareAccountListToUpd(
    Map<Id, string> accIdToAccRatingValueMap,
    Set<Id> accIds
  ) {
    List<Account> accListToUpd = new List<Account>();

    if (accIdToAccRatingValueMap.size() > 0) {
      for (Id acId : accIdToAccRatingValueMap.keySet()) {
        Account acc = new Account(Id = acId);
        acc.Rating = accIdToAccRatingValueMap.get(acId);
        accListToUpd.add(acc);
      }
    }

    return accListToUpd;
  }

  private string getRatingBasedOnCaseClosedCount(integer closedCaseCount) {
    string rating = '';

    if (closedCaseCount > 5) {
      rating = 'Hot';
    } else if (closedCaseCount >= 2 && closedCaseCount <= 5) {
      rating = 'Warm';
    } else {
      rating = 'Cold';
    }

    return rating;
  }
}
