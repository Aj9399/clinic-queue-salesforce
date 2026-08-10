/**
 * Public-facing status lookup for a single appointment, identified by its
 * record Id (an unguessable 18-char Salesforce Id, effectively a private
 * confirmation token). This is the ONLY read path guests get into
 * Appointment__c data -- it must never be widened into anything that lists
 * or searches appointments, since that would expose other patients'
 * names/phone numbers to the public.
 *
 * "without sharing" is required for the same reason as BookingService: the
 * guest's row-level sharing on Appointment__c is Private, so this needs to
 * bypass sharing to find the one record the caller already knows the Id of,
 * and to count how many active appointments are ahead of it in the queue.
 * WITH USER_MODE still enforces object/field CRUD via the guest permission
 * set -- only row-level visibility is bypassed, not FLS.
 */
public without sharing class PublicStatusService {
    public class StatusResult {
        @AuraEnabled
        public String patientName;
        @AuraEnabled
        public String status;
        @AuraEnabled
        public String slotTime;
        @AuraEnabled
        public Integer positionInQueue;
    }

    public static StatusResult getStatus(Id appointmentId) {
        List<Appointment__c> matches = [
            SELECT Id, Doctor__c, Appointment_Date__c, Patient_Name__c, Status__c, Slot_Time__c, Queue_Order__c
            FROM Appointment__c
            WHERE Id = :appointmentId
            WITH USER_MODE
            LIMIT 1
        ];
        if (matches.isEmpty()) {
            throw new QueueService.QueueException('Appointment not found.');
        }
        Appointment__c appt = matches[0];

        StatusResult result = new StatusResult();
        result.patientName = appt.Patient_Name__c;
        result.status = appt.Status__c;
        result.slotTime = TimeUtils.formatHHmm(appt.Slot_Time__c);

        if (appt.Status__c == QueueService.STATUS_BOOKED || appt.Status__c == QueueService.STATUS_CHECKED_IN) {
            Integer aheadCount = [
                SELECT COUNT()
                FROM Appointment__c
                WHERE Doctor__c = :appt.Doctor__c
                      AND Appointment_Date__c = :appt.Appointment_Date__c
                      AND Queue_Order__c < :appt.Queue_Order__c
                      AND Status__c IN (:QueueService.STATUS_BOOKED, :QueueService.STATUS_CHECKED_IN)
                WITH USER_MODE
            ];
            result.positionInQueue = aheadCount + 1;
        }
        return result;
    }
}
