@isTest
private class QueueControllerTest {
    @TestSetup
    static void setup() {
        Doctor__c doc = TestDataFactory.createDoctor('Dr. Test');
        TestDataFactory.createAppointment(doc.Id, Date.today(), Time.newInstance(17, 0, 0, 0), 0, 'Booked');
    }

    @isTest
    static void testGetQueueReturnsSeededAppointment() {
        Doctor__c doc = [SELECT Id FROM Doctor__c LIMIT 1];

        Test.startTest();
        List<QueueService.QueueItem> items = QueueController.getQueue(doc.Id, Date.today());
        Test.stopTest();

        System.assertEquals(1, items.size());
    }

    @isTest
    static void testCheckInThenCheckOutHappyPath() {
        Appointment__c appt = [SELECT Id FROM Appointment__c LIMIT 1];

        Test.startTest();
        QueueController.checkIn(appt.Id);
        QueueController.checkOut(appt.Id);
        Test.stopTest();

        Appointment__c updated = [SELECT Status__c FROM Appointment__c WHERE Id = :appt.Id];
        System.assertEquals('Completed', updated.Status__c);
    }

    @isTest
    static void testCheckOutBeforeCheckInThrowsAuraHandledExceptionWithMessage() {
        Appointment__c appt = [SELECT Id FROM Appointment__c LIMIT 1];

        Test.startTest();
        Boolean threw = false;
        try {
            QueueController.checkOut(appt.Id);
        } catch (AuraHandledException e) {
            threw = true;
            System.assertNotEquals(null, e.getMessage(), 'AuraHandledException message must survive the client boundary');
        }
        Test.stopTest();

        System.assert(threw, 'Expected checking out a not-yet-checked-in appointment to throw');
    }

    @isTest
    static void testSkipAppointmentPushesToEnd() {
        Doctor__c doc = [SELECT Id FROM Doctor__c LIMIT 1];
        Appointment__c first = [SELECT Id FROM Appointment__c LIMIT 1];
        TestDataFactory.createAppointment(doc.Id, Date.today(), Time.newInstance(17, 15, 0, 0), 1, 'Booked');

        Test.startTest();
        QueueController.skipAppointment(first.Id);
        Test.stopTest();

        List<Appointment__c> ordered = [SELECT Id FROM Appointment__c ORDER BY Queue_Order__c];
        System.assertEquals(first.Id, ordered[ordered.size() - 1].Id);
    }
}
