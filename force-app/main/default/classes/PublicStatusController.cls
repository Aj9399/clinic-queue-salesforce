/**
 * Thin @AuraEnabled entry point for the public patientStatus page. This is
 * the only Apex class besides BookingController granted to the site's Guest
 * User permission set -- QueueController must never be, since it returns
 * every patient's name and phone number for a doctor's whole day.
 */
public with sharing class PublicStatusController {
    // Deliberately NOT cacheable=true. This is called imperatively on a
    // 6-second poll loop (see patientStatus.js) -- cacheable=true would make
    // the Lightning Data Service serve every subsequent poll with the same
    // appointmentId from its client-side cache instead of ever hitting the
    // server again, which is exactly what was silently happening: the poll
    // "fired" in JS but never produced a real network call, and the page
    // stayed frozen on stale data indefinitely.
    @AuraEnabled
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
