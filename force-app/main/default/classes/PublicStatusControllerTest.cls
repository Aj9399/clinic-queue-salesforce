@isTest
private class PublicStatusControllerTest {
    @TestSetup
    static void setup() {
        Doctor__c doc = TestDataFactory.createDoctor('Dr. Test');
        TestDataFactory.createAppointment(doc.Id, Date.today(), Time.newInstance(17, 0, 0, 0), 0, 'Booked');
    }

    @isTest
    static void testGetStatusHappyPath() {
        Appointment__c appt = [SELECT Id FROM Appointment__c LIMIT 1];

        Test.startTest();
        PublicStatusService.StatusResult result = PublicStatusController.getStatus(appt.Id);
        Test.stopTest();

        System.assertEquals('Booked', result.status);
        System.assertEquals(1, result.positionInQueue);
    }

    @isTest
    static void testGetStatusThrowsAuraHandledExceptionForUnknownAppointment() {
        Doctor__c doc = [SELECT Id FROM Doctor__c LIMIT 1];
        Appointment__c appt = TestDataFactory.createAppointment(
            doc.Id,
            Date.today(),
            Time.newInstance(18, 0, 0, 0),
            5,
            'Booked'
        );
        Id apptId = appt.Id;
        delete appt;

        Test.startTest();
        Boolean threw = false;
        try {
            PublicStatusController.getStatus(apptId);
        } catch (AuraHandledException e) {
            threw = true;
            System.assertNotEquals(null, e.getMessage(), 'AuraHandledException message must survive the client boundary');
        }
        Test.stopTest();

        System.assert(threw, 'Expected a lookup for a deleted appointment to throw');
    }
}
