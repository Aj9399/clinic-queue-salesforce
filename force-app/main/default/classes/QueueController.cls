/**
 * Thin @AuraEnabled entry points for the admin queue console LWC.
 * All business logic lives in QueueService; this class only exposes it.
 */
public with sharing class QueueController {
    @AuraEnabled(cacheable=true)
    public static List<QueueService.QueueItem> getQueue(Id doctorId, Date apptDate) {
        return QueueService.getQueue(doctorId, apptDate);
    }

    @AuraEnabled
    public static void checkIn(Id appointmentId) {
        try {
            QueueService.checkIn(appointmentId);
        } catch (Exception e) {
            throw rethrowForClient(e);
        }
    }

    @AuraEnabled
    public static void checkOut(Id appointmentId) {
        try {
            QueueService.checkOut(appointmentId);
        } catch (Exception e) {
            throw rethrowForClient(e);
        }
    }

    @AuraEnabled
    public static void skipAppointment(Id appointmentId) {
        try {
            QueueService.skip(appointmentId);
        } catch (Exception e) {
            throw rethrowForClient(e);
        }
    }

    /**
     * AuraHandledException's constructor does not reliably surface the
     * message to the client unless setMessage is called explicitly first.
     */
    private static AuraHandledException rethrowForClient(Exception e) {
        AuraHandledException ex = new AuraHandledException(e.getMessage());
        ex.setMessage(e.getMessage());
        return ex;
    }
}
