const { onDocumentCreated, onDocumentUpdated, onDocumentDeleted } = require("firebase-functions/v2/firestore");
const admin = require('firebase-admin');
admin.initializeApp();

// Funkcja pomocnicza do wysyłania powiadomień
async function sendPushNotification(employeeId, title, body) {
    if (!employeeId) return;

    try {
        const userDoc = await admin.firestore().collection('users').doc(employeeId).get();
        if (!userDoc.exists) return;

        const fcmToken = userDoc.data().fcmToken;
        if (!fcmToken) {
            console.log(`Brak tokena FCM dla pracownika: ${employeeId}`);
            return;
        }

        const message = {
            notification: { title, body },
            token: fcmToken
        };

        const response = await admin.messaging().send(message);
        console.log('Powiadomienie wysłane:', response);
    } catch (error) {
        console.error('Błąd wysyłania powiadomienia:', error);
    }
}

// 1. Obsługa NOWEJ wizyty
exports.sendAppointmentNotification = onDocumentCreated("appointments/{appointmentId}", async (event) => {
    const data = event.data.data();
    await sendPushNotification(
        data.employeeId,
        'Nowa rezerwacja! 🎉',
        `${data.clientName} zapisał(a) się na ${data.serviceName} (${data.date} o godz. ${data.time}).`
    );
});

// 2. Obsługa ZMIANY wizyty (np. daty lub godziny)
exports.updateAppointmentNotification = onDocumentUpdated("appointments/{appointmentId}", async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    // Wyślij tylko jeśli zmieniła się data lub godzina
    if (before.date !== after.date || before.time !== after.time) {
        await sendPushNotification(
            after.employeeId,
            'Zmiana terminu wizyty 📅',
            `Wizyta ${after.clientName} została zmieniona na ${after.date} godz. ${after.time}.`
        );
    }
});

// 3. Obsługa KASOWANIA wizyty
exports.deleteAppointmentNotification = onDocumentDeleted("appointments/{appointmentId}", async (event) => {
    const data = event.data.data();
    await sendPushNotification(
        data.employeeId,
        'Wizyta anulowana ❌',
        `Klientka ${data.clientName} odwołała wizytę na ${data.serviceName}.`
    );
});