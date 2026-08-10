/**
 * Publishes one Queue_Update__e per distinct doctor+date whose queue
 * actually changed (new booking, status transition, or reorder), so every
 * open queue console can refetch and stay live. Bulk-safe: a single
 * transaction touching many appointments still only publishes one event
 * per affected doctor+date pair, not one per record.
 */
public with sharing class AppointmentTriggerHandler {
    public static void handleAfterSave(List<Appointment__c> newRecords, Map<Id, Appointment__c> oldMap) {
        Set<String> changedKeys = new Set<String>();

        for (Appointment__c appt : newRecords) {
            Appointment__c oldAppt = (oldMap == null) ? null : oldMap.get(appt.Id);
            Boolean isNew = (oldAppt == null);
            Boolean relevantChange =
                isNew ||
                appt.Status__c != oldAppt.Status__c ||
                appt.Queue_Order__c != oldAppt.Queue_Order__c;

            if (relevantChange && appt.Doctor__c != null && appt.Appointment_Date__c != null) {
                changedKeys.add(appt.Doctor__c + '|' + String.valueOf(appt.Appointment_Date__c));
            }
        }

        if (changedKeys.isEmpty()) {
            return;
        }

        List<Queue_Update__e> events = new List<Queue_Update__e>();
        for (String key : changedKeys) {
            List<String> parts = key.split('\\|');
            events.add(
                new Queue_Update__e(
                    Doctor_Id__c = parts[0],
                    Appointment_Date__c = Date.valueOf(parts[1])
                )
            );
        }
        EventBus.publish(events);
    }
}
