trigger RoleChangePlatformEventTrigger on RoleChange__e (after insert) {
    RoleChangePlatformEventTriggerHandler.updateUsersRoleBasedOnList(Trigger.new);
}