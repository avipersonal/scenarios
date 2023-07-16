public with sharing class JobApplicationController {
    public static integer index = 0;
    
    @AuraEnabled(cacheable=true)
    public static JobApplicationWrapper getJobApplications(string i, integer pc) {
        JobApplicationWrapper jobAppWrapper = new JobApplicationWrapper();
        Set<Id> jobAppId = new Set<Id>();

        integer totalRows = [Select Count() from Job_Application__c];
        // System.debug('TOTAL ROWS : ' + totalRows);
        integer r = (Math.floor((totalRows)/10)).intValue() + 1;
        // System.debug('r : ' + r);

        switch on i {
            when 'start' {
                pc = 0;
                if(r == 1) {
                   jobAppWrapper.isLast = true;
                   jobAppWrapper.isFirst = true;
                } else {
                   jobAppWrapper.isLast = false;
                }
                jobAppWrapper.isFirst = true;
            }
            when 'end' {
                pc = r - 1;
                jobAppWrapper.isLast = true;
                jobAppWrapper.isFirst = false;
            }
            when 'back' {
                jobAppWrapper.isLast = false;
                pc = pc - 1;
                if(pc == 0) {
                    jobAppWrapper.isFirst = true;
                } else {
                    jobAppWrapper.isFirst = false;
                }
            }
            when 'forward' {
                jobAppWrapper.isFirst = false;
                pc = pc + 1;
                if(pc == (r - 1)){
                    jobAppWrapper.isLast = true;
                } else {
                    jobAppWrapper.isLast = false;
                }
            }
        }

        integer n = pc*10;
        System.debug('n : ' + n);

        list<Job_Application__c> jobAppList = [SELECT Name, Applicant_Name__c, Position_Name__c, Application_Date__c from Job_Application__c LIMIT 10 OFFSET :n];
        for(Job_Application__c ja : jobAppList) {
            jobAppId.add(ja.Id);
        }

        if(jobAppId.size() > 0) {
            jobAppWrapper.jobAppIdToCdIdMap = createMapOfJobAppIdAndCdId(jobAppId);
        }

        jobAppWrapper.jobApplicationList = jobAppList;
        jobAppWrapper.pageIndex = pc;

        System.debug(JSON.serializepretty(jobAppWrapper));
        
        return jobAppWrapper;
    }

    public static map<Id, Id> createMapOfJobAppIdAndCdId(Set<Id> jobAppId) {
        Map<Id, Id> jAIdToCdIdMap = new Map<Id, Id>();

        if(jobAppId.size() > 0) {
            string cdTitle = '%Resume%';

            List<ContentDocumentLink> cdLinks = [SELECT LinkedEntityId, ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId IN :jobAppId AND ContentDocument.Title LIKE :cdTitle];

            for (ContentDocumentLink cdl : cdLinks) {
                jAIdToCdIdMap.put(cdl.LinkedEntityId, cdl.contentdocumentId);
            }

            if(jAIdToCdIdMap.size() > 0) {
               for (Id jaId : jobAppId) {
                    if(!jAIdToCdIdMap.containskey(jaId)){
                        jAIdToCdIdMap.put(jaId, null);
                    }
                }
            }
            
        }   

        return jAIdToCdIdMap;
    }

    private class JobApplicationWrapper {
        @AuraEnabled 
        public list<Job_Application__c> jobApplicationList {get; set;}
        @AuraEnabled
        public integer pageIndex {get; set;}
        @AuraEnabled 
        public boolean isLast {get; set;}
        @AuraEnabled 
        public boolean isFirst {get; set;}
        @AuraEnabled 
        public Map<Id, Id> jobAppIdToCdIdMap {get; set;}
    }

    @AuraEnabled(cacheable=true)
    public static list<Job_Application__c> getJobApplicationsBasedOnSearch(string searchIndex) {
        list<Job_Application__c> jobApplicationList = new List<Job_Application__c>();

        if(String.isNotBlank(searchIndex) && searchIndex.length() > 1) {
            string chgIndex = '*' + searchIndex + '*';
            string query = 'FIND :chgIndex IN ALL FIELDS Returning Job_Application__c(Name, Applicant_Name__c, Position_Name__c, Application_Date__c LIMIT 10)';

            string refinedQuery = String.escapeSingleQuotes(query);
            list<list<sobject>> queryResult = Search.query(refinedQuery);
            jobApplicationList = queryResult[0];
        } else {
            jobApplicationList = getJobApplications('start', 0).jobApplicationList;
        }
 
        System.debug('JOB APPLICATION LIST -> ' + jobApplicationList);
        return jobApplicationList;
    }

    @AuraEnabled 
    public static string createJobApplicationWithDocumentShare(string fields, string cdId) {
        string jAId;
        List<ContentDocumentLink> cdLinksToInsert;

        Job_Application__c ja = (Job_Application__c) JSON.deserialize(fields, Job_Application__c.class);
        if(ja != null) {
            insert ja;
            jAId = ja.Id;

            if(cdId != null) {
                ContentWorkspace cw = [SELECT Id FROM ContentWorkspace WHERE Name = 'Resume'];

                cdLinksToInsert = new List<ContentDocumentLink>{new ContentDocumentLink(LinkedEntityId=cw.Id, ContentDocumentId=cdId, ShareType='I', Visibility='AllUsers'), new ContentDocumentLink(LinkedEntityId=ja.Id, ContentDocumentId=cdId, ShareType='I', Visibility='AllUsers')};

                if(cdLinksToInsert.size() > 0) {
                    insert cdLinksToInsert;
                }
            }

        } 

        return jAId;
    }
}

