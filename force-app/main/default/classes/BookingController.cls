/**
 * Thin @AuraEnabled entry points for the patient-facing booking LWC.
 * All business logic lives in BookingService; this class only exposes it.
 */
public with sharing class BookingController {
    @AuraEnabled(cacheable=true)
    public static List<Doctor__c> getDoctors() {
        return [SELECT Id, Name, Clinic_Name__c FROM Doctor__c WITH USER_MODE ORDER BY Name];
    }

    @AuraEnabled(cacheable=true)
    public static List<BookingService.SlotOption> getAvailableSlots(Id doctorId, Date apptDate) {
        return BookingService.getAvailableSlots(doctorId, apptDate);
    }

    @AuraEnabled
    public static Id bookAppointment(
        Id doctorId,
        Date apptDate,
        Time slotTime,
        String patientName,
        String patientPhone
    ) {
        try {
            return BookingService.bookAppointment(doctorId, apptDate, slotTime, patientName, patientPhone);
        } catch (Exception e) {
            AuraHandledException ex = new AuraHandledException(e.getMessage());
            ex.setMessage(e.getMessage());
            throw ex;
        }
    }
}
