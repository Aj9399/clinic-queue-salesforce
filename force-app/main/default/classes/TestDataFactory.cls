@isTest
public class TestDataFactory {
    public static Doctor__c createDoctor(String doctorName) {
        Doctor__c doc = new Doctor__c(
            Name = doctorName,
            Clinic_Name__c = 'Test Clinic',
            Start_Time__c = Time.newInstance(17, 0, 0, 0),
            End_Time__c = Time.newInstance(21, 0, 0, 0),
            Slot_Minutes__c = 15
        );
        insert doc;
        return doc;
    }

    public static Appointment__c createAppointment(
        Id doctorId,
        Date apptDate,
        Time slotTime,
        Integer queueOrder,
        String status
    ) {
        Appointment__c appt = new Appointment__c(
            Doctor__c = doctorId,
            Appointment_Date__c = apptDate,
            Slot_Time__c = slotTime,
            Patient_Name__c = 'Test Patient',
            Patient_Phone__c = '9999999999',
            Queue_Order__c = queueOrder,
            Status__c = status
        );
        insert appt;
        return appt;
    }
}
