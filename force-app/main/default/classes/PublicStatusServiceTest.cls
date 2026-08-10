@isTest
private class PublicStatusServiceTest {
    @TestSetup
    static void setup() {
        Doctor__c doc = TestDataFactory.createDoctor('Dr. Test');
        TestDataFactory.createAppointment(doc.Id, Date.today(), Time.newInstance(17, 0, 0, 0), 0, 'Booked');
        TestDataFactory.createAppointment(doc.Id, Date.today(), Time.newInstance(17, 15, 0, 0), 1, 'Booked');
    }

    @isTest
    static void testGetStatusReturnsPositionForActiveAppointment() {
        List<Appointment__c> appts = [SELECT Id FROM Appointment__c ORDER BY Queue_Order__c];

        Test.startTest();
        PublicStatusService.StatusResult result = PublicStatusService.getStatus(appts[1].Id);
        Test.stopTest();

        System.assertEquals('Booked', result.status);
        System.assertEquals(2, result.positionInQueue);
    }

    @isTest
    static void testGetStatusOmitsPositionForCompletedAppointment() {
        Appointment__c appt = [SELECT Id FROM Appointment__c ORDER BY Queue_Order__c LIMIT 1];
        QueueService.checkIn(appt.Id);
        QueueService.checkOut(appt.Id);

        Test.startTest();
        PublicStatusService.StatusResult result = PublicStatusService.getStatus(appt.Id);
        Test.stopTest();

        System.assertEquals('Completed', result.status);
        System.assertEquals(null, result.positionInQueue);
    }

    @isTest
    static void testGetStatusThrowsForDeletedAppointment() {
        Doctor__c doc = [SELECT Id FROM Doctor__c LIMIT 1];
        Appointment__c appt = TestDataFactory.createAppointment(
            doc.Id,
            Date.today(),
            Time.newInstance(18, 0, 0, 0),
            2,
            'Booked'
        );
        Id apptId = appt.Id;
        delete appt;

        Test.startTest();
        Boolean threw = false;
        try {
            PublicStatusService.getStatus(apptId);
        } catch (QueueService.QueueException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Expected a lookup for a deleted appointment to throw');
    }
}
