trigger AppointmentTrigger on Appointment__c (after insert, after update) {
    AppointmentTriggerHandler.handleAfterSave(Trigger.new, Trigger.oldMap);
}
