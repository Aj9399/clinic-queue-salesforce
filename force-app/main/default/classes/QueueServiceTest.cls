@isTest
private class QueueServiceTest {
    @TestSetup
    static void setup() {
        Doctor__c doc = TestDataFactory.createDoctor('Dr. Test');
        Date today = Date.today();
        TestDataFactory.createAppointment(doc.Id, today, Time.newInstance(17, 0, 0, 0), 0, 'Booked');
        TestDataFactory.createAppointment(doc.Id, today, Time.newInstance(17, 15, 0, 0), 1, 'Booked');
        TestDataFactory.createAppointment(doc.Id, today, Time.newInstance(17, 30, 0, 0), 2, 'Booked');
    }

    @isTest
    static void testGetQueueOrdersByQueueOrderAndComputesPosition() {
        Doctor__c doc = [SELECT Id FROM Doctor__c LIMIT 1];

        Test.startTest();
        List<QueueService.QueueItem> items = QueueService.getQueue(doc.Id, Date.today());
        Test.stopTest();

        System.assertEquals(3, items.size(), 'Expected all three seeded appointments');
        System.assertEquals(1, items[0].positionInQueue);
        System.assertEquals(2, items[1].positionInQueue);
        System.assertEquals(3, items[2].positionInQueue);
    }

    @isTest
    static void testCheckInTransitionsStatusAndStampsTime() {
        Appointment__c appt = [SELECT Id FROM Appointment__c ORDER BY Queue_Order__c LIMIT 1];

        Test.startTest();
        QueueService.checkIn(appt.Id);
        Test.stopTest();

        Appointment__c updated = [SELECT Status__c, Checked_In_At__c FROM Appointment__c WHERE Id = :appt.Id];
        System.assertEquals('Checked In', updated.Status__c);
        System.assertNotEquals(null, updated.Checked_In_At__c);
    }

    @isTest
    static void testCheckInRejectsAlreadyCheckedInAppointment() {
        Appointment__c appt = [SELECT Id FROM Appointment__c ORDER BY Queue_Order__c LIMIT 1];
        QueueService.checkIn(appt.Id);

        Test.startTest();
        Boolean threw = false;
        try {
            QueueService.checkIn(appt.Id);
        } catch (QueueService.QueueException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Expected checking in an already-checked-in appointment to throw');
    }

    @isTest
    static void testCheckOutTransitionsStatusAndStampsTime() {
        Appointment__c appt = [SELECT Id FROM Appointment__c ORDER BY Queue_Order__c LIMIT 1];
        QueueService.checkIn(appt.Id);

        Test.startTest();
        QueueService.checkOut(appt.Id);
        Test.stopTest();

        Appointment__c updated = [SELECT Status__c, Checked_Out_At__c FROM Appointment__c WHERE Id = :appt.Id];
        System.assertEquals('Completed', updated.Status__c);
        System.assertNotEquals(null, updated.Checked_Out_At__c);
    }

    @isTest
    static void testCheckOutRejectsAppointmentThatWasNeverCheckedIn() {
        Appointment__c appt = [SELECT Id FROM Appointment__c ORDER BY Queue_Order__c LIMIT 1];

        Test.startTest();
        Boolean threw = false;
        try {
            QueueService.checkOut(appt.Id);
        } catch (QueueService.QueueException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Expected checking out a not-yet-checked-in appointment to throw');
    }

    @isTest
    static void testSkipMovesAppointmentToEndOfActiveQueue() {
        List<Appointment__c> appts = [SELECT Id, Queue_Order__c FROM Appointment__c ORDER BY Queue_Order__c];
        Appointment__c first = appts[0];

        Test.startTest();
        QueueService.skip(first.Id);
        Test.stopTest();

        List<Appointment__c> reordered = [SELECT Id, Queue_Order__c FROM Appointment__c ORDER BY Queue_Order__c];
        System.assertNotEquals(first.Id, reordered[0].Id, 'Skipped appointment should no longer be first');
        System.assertEquals(
            first.Id,
            reordered[reordered.size() - 1].Id,
            'Skipped appointment should be pushed to the end of the active queue'
        );
    }

    @isTest
    static void testSkipRejectsNonBookedAppointment() {
        Appointment__c appt = [SELECT Id FROM Appointment__c ORDER BY Queue_Order__c LIMIT 1];
        QueueService.checkIn(appt.Id);

        Test.startTest();
        Boolean threw = false;
        try {
            QueueService.skip(appt.Id);
        } catch (QueueService.QueueException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Expected skipping a checked-in appointment to throw');
    }
}
