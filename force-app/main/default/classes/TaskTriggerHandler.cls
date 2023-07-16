public with sharing class TaskTriggerHandler extends Triggerhandler {
  List<Task> taskListNew = new List<Task>();
  List<Task> taskListOld = new List<Task>();
  Map<Id, Task> taskMapOld = new Map<Id, Task>();

  public TaskTriggerHandler() {
    taskListNew = (List<Task>) Trigger.new;
    taskListOld = (List<Task>) Trigger.old;
    taskMapOld = (Map<Id, Task>) Trigger.oldMap;
  }

  protected override void afterInsert() {
    updateOppStatusBasedOnTaskStatus(taskListNew, taskMapOld);
  }

  protected override void afterUpdate() {
    updateOppStatusBasedOnTaskStatus(taskListNew, taskMapOld);
  }

  private void updateOppStatusBasedOnTaskStatus(
    List<Task> taskListNew,
    Map<Id, Task> taskMapOld
  ) {
    Set<Id> oppIds = new Set<Id>();
    List<Opportunity> oppListToUpd = new List<Opportunity>();
    Map<Id, string> oppIdToOppStatusMap = new Map<Id, string>();
    boolean haveOppIds = false;
    boolean isOppIdToStringMapHaveValues = false;
    boolean isOppListToUpdHaveValues = false;

    oppIds = getOpportunityIds(taskListNew, taskMapOld);
    HaveOppIds = oppIds.size() > 0;

    if (haveOppIds) {
      oppIdToOppStatusMap = getMapOfOppIdToStatus(oppIds);
      isOppIdToStringMapHaveValues = oppIdToOppStatusMap.size() > 0;

      if (isOppIdToStringMapHaveValues) {
        oppListToUpd = getTaskListToUpdate(oppIdToOppStatusMap);
        isOppListToUpdHaveValues = oppListToUpd.size() > 0;

        if (isOppListToUpdHaveValues) {
          update oppListToUpd;
        }
      }
    }
  }

  private Set<Id> getOpportunityIds(
    List<Task> taskListNew,
    Map<Id, Task> taskMapOld
  ) {
    Set<Id> oppIds = new Set<Id>();

    for (Task t : taskListNew) {
      if (Trigger.isInsert) {
        if (t.whatId != null && string.valueof(t.whatId).startsWith('006')) {
          oppIds.add(t.WhatId);
        }
      } else if (Trigger.isUpdate) {
        if (
          string.valueof(t.whatId).startsWith('006') &&
          (t.status != taskMapOld.get(t.Id).status)
        ) {
          oppIds.add(t.whatId);
        }
        if (t.whatId != taskMapOld.get(t.Id).whatId) {
          if (
            taskMapOld.get(t.Id).whatId != null &&
            string.valueOf(taskMapOld.get(t.Id).whatId).startsWith('006')
          ) {
            oppIds.add(taskMapOld.get(t.Id).WhatId);
          }
          if (t.whatId != null && string.valueOf(t.WhatId).startsWith('006')) {
            oppIds.add(t.WhatId);
          }
        }
      }
    }

    return oppIds;
  }

  private Map<Id, string> getMapOfOppIdToStatus(Set<Id> oppIds) {
    Map<Id, string> oppIdToOppStatusName = new Map<Id, string>();

    List<AggregateResult> result = [
      SELECT COUNT(Id), whatId
      FROM Task
      WHERE WhatId IN :oppIds AND Status = 'In Progress'
      GROUP BY whatId
    ];

    for (AggregateResult ar : result) {
      oppIdToOppStatusName.put((Id) ar.get('whatId'), 'In Progress');
    }

    for (Id opId : oppIds) {
      if (!oppIdToOppStatusName.containsKey(opId)) {
        oppIdToOppStatusName.put(opId, 'Pending');
      }
    }

    return oppIdToOppStatusName;
  }

  private list<Opportunity> getTaskListToUpdate(
    Map<Id, string> OppIdToOppStatusName
  ) {
    List<Opportunity> oppListToUpd = new List<Opportunity>();

    for (Id oppId : OppIdToOppStatusName.keySet()) {
      Opportunity opp = new Opportunity(Id = oppId);

      opp.Status__c = OppIdToOppStatusName.get(oppId);

      oppListToUpd.add(opp);
    }

    return oppListToUpd;
  }
}

