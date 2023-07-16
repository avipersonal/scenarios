public with sharing class RoleChangePlatformEventTriggerHandler {
   public static void updateUsersRoleBasedOnList(list<RoleChange__e> roleChangeEventsList){
      Set<string> roleNames = getAllRoleNames(roleChangeEventsList);
      boolean isRoleNames = roleNames.size() > 0;
      if(isRoleNames){
        list<UserRole> roles = getRoleRecordsBasedOnRoleNames(roleNames);
        boolean isRolesPresent = roles.size() > 0;
        if(isRolesPresent) {
           map<string, Id> roleNameIdMap = createMapOfRoleNameWithId(roles);
           boolean isRoleNameIdMapFilled = roleNameIdMap.size() > 0;
           if(isRoleNameIdMapFilled){
              list<User> usersToUpd = getUserRecordsToBeUpd(roleChangeEventsList, roleNameIdMap);
                 boolean isUsersListToUpdFilled = usersToUpd.size() > 0;
                 if(isUsersListToUpdFilled){
                    update usersToUpd;
                }
            } 
        }
      }  
    }

    private static Set<string> getAllRoleNames(list<RoleChange__e> roleChangeEventsList) {
        Set<string> roleNames = new Set<string>();
        for(RoleChange__e rc : roleChangeEventsList){
           roleNames.add(rc.RoleId__c);
        }
        return roleNames;
    }

    private static list<UserRole> getRoleRecordsBasedOnRoleNames(Set<string> roleNames) {
        return [Select Id, Name from UserRole where Name IN :roleNames];
    }
      
    private static map<string, Id> createMapOfRoleNameWithId(list<UserRole> roles) {
        map<string, Id> roleNameIdMap = new map<string, Id>();
        for(UserRole ur : roles){
           roleNameIdMap.put(ur.Name, ur.Id);
        }
        return roleNameIdMap;
    }

    private static list<User> getUserRecordsToBeUpd(List<RoleChange__e> roleChangeEventList, map<string, Id> roleNameIdMap) {
        list<User> usersToUpd = new list<User>();
        for(RoleChange__e rc : roleChangeEventList){
            if(roleNameIdMap.containsKey(rc.RoleId__c)){
                User u = new User(Id=rc.UserId__c);
                u.UserRoleId = roleNameIdMap.get(rc.RoleId__c);
                usersToUpd.add(u);
            }
        }
        return usersToUpd;
    }

}