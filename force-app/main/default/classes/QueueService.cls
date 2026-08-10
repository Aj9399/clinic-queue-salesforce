/**
 * Business logic for the live appointment queue: fetching today's queue with
 * computed position, and the check-in / check-out / skip state transitions.
 * Kept independent of @AuraEnabled controllers so it stays unit-testable and
 * reusable (e.g. from a future Experience Cloud controller).
 */
public with sharing class QueueService {
    public static final String STATUS_BOOKED = 'Booked';
    public static final String STATUS_CHECKED_IN = 'Checked In';
    public static final String STATUS_COMPLETED = 'Completed';
    public static final String STATUS_SKIPPED = 'Skipped';
    public static final String STATUS_CANCELLED = 'Cancelled';

    private static final Set<String> ACTIVE_STATUSES = new Set<String>{
        STATUS_BOOKED,
        STATUS_CHECKED_IN
    };

    public class QueueException extends Exception {
    }

    public class QueueItem {
        @AuraEnabled
        public Id id;
        @AuraEnabled
        public String appointmentName;
        @AuraEnabled
        public String patientName;
        @AuraEnabled
        public String patientPhone;
        @AuraEnabled
        public String status;
        @AuraEnabled
        public Time slotTime;
        @AuraEnabled
        public Decimal queueOrder;
        @AuraEnabled
        public Integer positionInQueue;
        @AuraEnabled
        public Datetime checkedInAt;
        @AuraEnabled
        public Datetime checkedOutAt;
    }

    public static List<QueueItem> getQueue(Id doctorId, Date apptDate) {
        List<Appointment__c> appts = [
            SELECT Id, Name, Patient_Name__c, Patient_Phone__c, Status__c,
                   Slot_Time__c, Queue_Order__c, Checked_In_At__c, Checked_Out_At__c
            FROM Appointment__c
            WHERE Doctor__c = :doctorId AND Appointment_Date__c = :apptDate
            WITH USER_MODE
            ORDER BY Queue_Order__c ASC
        ];

        List<QueueItem> items = new List<QueueItem>();
        Integer position = 0;
        for (Appointment__c a : appts) {
            QueueItem item = new QueueItem();
            item.id = a.Id;
            item.appointmentName = a.Name;
            item.patientName = a.Patient_Name__c;
            item.patientPhone = a.Patient_Phone__c;
            item.status = a.Status__c;
            item.slotTime = a.Slot_Time__c;
            item.queueOrder = a.Queue_Order__c;
            item.checkedInAt = a.Checked_In_At__c;
            item.checkedOutAt = a.Checked_Out_At__c;
            if (ACTIVE_STATUSES.contains(a.Status__c)) {
                position++;
                item.positionInQueue = position;
            }
            items.add(item);
        }
        return items;
    }

    public static void checkIn(Id appointmentId) {
        Appointment__c appt = getForUpdate(appointmentId);
        if (appt.Status__c != STATUS_BOOKED) {
            throw new QueueException('Only booked appointments can be checked in.');
        }
        appt.Status__c = STATUS_CHECKED_IN;
        appt.Checked_In_At__c = Datetime.now();
        update as user appt;
    }

    public static void checkOut(Id appointmentId) {
        Appointment__c appt = getForUpdate(appointmentId);
        if (appt.Status__c != STATUS_CHECKED_IN) {
            throw new QueueException('Only checked-in appointments can be checked out.');
        }
        appt.Status__c = STATUS_COMPLETED;
        appt.Checked_Out_At__c = Datetime.now();
        update as user appt;
    }

    /**
     * No-show handling: keep the appointment Booked (the patient may still turn
     * up) but push it behind everyone currently active in the queue, so the
     * next patient is served without waiting on someone who isn't there.
     */
    public static void skip(Id appointmentId) {
        Appointment__c appt = getForUpdate(appointmentId);
        if (appt.Status__c != STATUS_BOOKED) {
            throw new QueueException('Only booked appointments can be skipped.');
        }

        AggregateResult maxResult = [
            SELECT MAX(Queue_Order__c) maxOrder
            FROM Appointment__c
            WHERE Doctor__c = :appt.Doctor__c
                  AND Appointment_Date__c = :appt.Appointment_Date__c
                  AND Status__c IN :ACTIVE_STATUSES
            WITH USER_MODE
        ];
        Decimal maxOrder = (Decimal) maxResult.get('maxOrder');
        appt.Queue_Order__c = (maxOrder == null ? 0 : maxOrder) + 1;
        update as user appt;
    }

    private static Appointment__c getForUpdate(Id appointmentId) {
        return [
            SELECT Id, Doctor__c, Appointment_Date__c, Status__c, Queue_Order__c
            FROM Appointment__c
            WHERE Id = :appointmentId
            WITH USER_MODE
            LIMIT 1
        ];
    }
}
