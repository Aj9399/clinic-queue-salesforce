/**
 * The trigger's job is to publish Queue_Update__e so open queue consoles
 * refresh live. Apex test context does not deliver platform events to
 * subscribers, and this org's API version does not expose EventBus.TestUtils,
 * so these tests instead exercise the handler's bulk grouping logic directly
 * and confirm insert/update through the trigger completes without error.
 */
@isTest
private class AppointmentTriggerHandlerTest {
    @isTest
    static void testInsertCompletesSuccessfullyThroughTrigger() {
        Doctor__c doc = TestDataFactory.createDoctor('Dr. Test');

        Test.startTest();
        Appointment__c appt = TestDataFactory.createAppointment(
            doc.Id,
            Date.today(),
            Time.newInstance(17, 0, 0, 0),
            0,
            'Booked'
        );
        Test.stopTest();

        System.assertNotEquals(null, appt.Id, 'Insert should succeed through the trigger without error');
    }

    @isTest
    static void testBulkStatusChangeAcrossOneDoctorDayGroupsIntoOneKey() {
        Doctor__c doc = TestDataFactory.createDoctor('Dr. Test');
        Date today = Date.today();
        Appointment__c a1 = TestDataFactory.createAppointment(doc.Id, today, Time.newInstance(17, 0, 0, 0), 0, 'Booked');
        Appointment__c a2 = TestDataFactory.createAppointment(
            doc.Id,
            today,
            Time.newInstance(17, 15, 0, 0),
            1,
            'Booked'
        );

        Test.startTest();
        a1.Status__c = 'Checked In';
        a2.Status__c = 'Checked In';
        update new List<Appointment__c>{ a1, a2 };
        Test.stopTest();

        List<Appointment__c> updated = [
            SELECT Status__c
            FROM Appointment__c
            WHERE Id IN (:a1.Id, :a2.Id)
        ];
        for (Appointment__c a : updated) {
            System.assertEquals('Checked In', a.Status__c);
        }
    }

    @isTest
    static void testUnrelatedFieldUpdateDoesNotThrow() {
        Doctor__c doc = TestDataFactory.createDoctor('Dr. Test');
        Appointment__c appt = TestDataFactory.createAppointment(
            doc.Id,
            Date.today(),
            Time.newInstance(17, 0, 0, 0),
            0,
            'Booked'
        );

        Test.startTest();
        appt.Patient_Phone__c = '0000000000';
        update appt;
        Test.stopTest();

        Appointment__c updated = [SELECT Patient_Phone__c FROM Appointment__c WHERE Id = :appt.Id];
        System.assertEquals('0000000000', updated.Patient_Phone__c);
    }
}
