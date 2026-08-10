/**
 * Thin @AuraEnabled entry point for the public patientStatus page. This is
 * the only Apex class besides BookingController granted to the site's Guest
 * User permission set -- QueueController must never be, since it returns
 * every patient's name and phone number for a doctor's whole day.
 */
public with sharing class PublicStatusController {
    @AuraEnabled(cacheable=true)
    public static PublicStatusService.StatusResult getStatus(Id appointmentId) {
        try {
            return PublicStatusService.getStatus(appointmentId);
        } catch (Exception e) {
            AuraHandledException ex = new AuraHandledException(e.getMessage());
            ex.setMessage(e.getMessage());
            throw ex;
        }
    }
}
