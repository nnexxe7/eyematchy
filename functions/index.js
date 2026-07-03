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
            // 🚀 WAŻNE: Dodane ustawienia, żeby działały wyskakujące banery na Androidzie
            android: {
                notification: {
                    channelId: "high_importance_channel",
                    priority: "max",
                    sound: "default"
                }
            },
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

// 2. Obsługa AKTUALIZACJI wizyty (Zmiana daty/godziny LUB wystawienie oceny)
exports.updateAppointmentNotification = onDocumentUpdated("appointments/{appointmentId}", async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    // Sytuacja A: Zmieniła się data lub godzina
    if (before.date !== after.date || before.time !== after.time) {
        await sendPushNotification(
            after.employeeId,
            'Zmiana terminu wizyty 📅',
            `Wizyta ${after.clientName} została zmieniona na ${after.date} godz. ${after.time}.`
        );
    }

    // 🚀 Sytuacja B: Klientka właśnie wystawiła ocenę (isRated zmieniło się z false na true)
    if (before.isRated === false && after.isRated === true) {
        const rating = after.rating || 5;
        const clientName = after.clientNameForReview || after.clientName || "Klientka";

        await sendPushNotification(
            after.employeeId,
            'Masz nową opinię! ⭐',
            `${clientName} ocenił(a) Twoją usługę na ${rating}/5.`
        );
    }
});

// 3. Obsługa KASOWANIA wizyty
exports.deleteAppointmentNotification = onDocumentDeleted("appointments/{appointmentId}", async (event) => {
    const data = event.data.data();

    if (data.clientId) {
        await sendPushNotification(
            data.clientId,
            'Wizyta odwołana ❌',
            `Twój salon odwołał wizytę na ${data.serviceName} (${data.date} o godz. ${data.time}). Skontaktuj się z salonem, aby ustalić nowy termin.`
        );
    }
});