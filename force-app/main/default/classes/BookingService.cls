/**
 * Business logic for patient-facing booking: computing the slot grid for a
 * doctor's day and creating a new appointment. Queue_Order__c is seeded from
 * the slot's position in the day (not insertion order), so appointments
 * booked out of time order still serve in time order until something moves.
 *
 * Slot times cross the @AuraEnabled boundary as "HH:mm" strings, not Apex
 * Time -- see TimeUtils for why.
 */
public with sharing class BookingService {
    public class SlotOption {
        @AuraEnabled
        public String slotTime;
        @AuraEnabled
        public Boolean isAvailable;
    }

    public static List<SlotOption> getAvailableSlots(Id doctorId, Date apptDate) {
        Doctor__c doc = getDoctor(doctorId);

        Set<Time> takenSlots = new Set<Time>();
        for (Appointment__c a : [
            SELECT Slot_Time__c
            FROM Appointment__c
            WHERE Doctor__c = :doctorId
                  AND Appointment_Date__c = :apptDate
                  AND Status__c IN (
                      :QueueService.STATUS_BOOKED,
                      :QueueService.STATUS_CHECKED_IN
                  )
            WITH USER_MODE
        ]) {
            takenSlots.add(a.Slot_Time__c);
        }

        List<SlotOption> options = new List<SlotOption>();
        Integer stepMs = Integer.valueOf(doc.Slot_Minutes__c) * 60 * 1000;
        Time cursor = doc.Start_Time__c;
        while (cursor < doc.End_Time__c) {
            SlotOption opt = new SlotOption();
            opt.slotTime = TimeUtils.formatHHmm(cursor);
            opt.isAvailable = !takenSlots.contains(cursor);
            options.add(opt);
            cursor = cursor.addMilliseconds(stepMs);
        }
        return options;
    }

    public static Id bookAppointment(
        Id doctorId,
        Date apptDate,
        String slotTimeStr,
        String patientName,
        String patientPhone
    ) {
        if (String.isBlank(patientName) || String.isBlank(patientPhone)) {
            throw new QueueService.QueueException('Patient name and phone are required.');
        }
        if (String.isBlank(slotTimeStr)) {
            throw new QueueService.QueueException('A slot time is required.');
        }

        Time slotTime = TimeUtils.parseHHmm(slotTimeStr);

        List<Appointment__c> existing = [
            SELECT Id
            FROM Appointment__c
            WHERE Doctor__c = :doctorId
                  AND Appointment_Date__c = :apptDate
                  AND Slot_Time__c = :slotTime
                  AND Status__c IN (
                      :QueueService.STATUS_BOOKED,
                      :QueueService.STATUS_CHECKED_IN
                  )
            WITH USER_MODE
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            throw new QueueService.QueueException('That slot was just taken. Please choose another.');
        }

        Doctor__c doc = getDoctor(doctorId);
        Integer slotIndex = (minutesSinceMidnight(slotTime) - minutesSinceMidnight(doc.Start_Time__c))
            / Integer.valueOf(doc.Slot_Minutes__c);

        Appointment__c appt = new Appointment__c(
            Doctor__c = doctorId,
            Appointment_Date__c = apptDate,
            Slot_Time__c = slotTime,
            Patient_Name__c = patientName,
            Patient_Phone__c = patientPhone,
            Status__c = QueueService.STATUS_BOOKED,
            Queue_Order__c = slotIndex
        );
        insert as user appt;
        return appt.Id;
    }

    private static Doctor__c getDoctor(Id doctorId) {
        return [
            SELECT Id, Start_Time__c, End_Time__c, Slot_Minutes__c
            FROM Doctor__c
            WHERE Id = :doctorId
            WITH USER_MODE
            LIMIT 1
        ];
    }

    private static Integer minutesSinceMidnight(Time t) {
        return t.hour() * 60 + t.minute();
    }
}
