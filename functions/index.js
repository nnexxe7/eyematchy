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

// 2. Obsługa AKTUALIZACJI wizyty (Zmiana daty/godziny, przypisania LUB wystawienie oceny)
exports.updateAppointmentNotification = onDocumentUpdated("appointments/{appointmentId}", async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    // 🚀 Sytuacja A1: Wizyta została przeniesiona do INNEJ stylistki
    if (before.employeeId !== after.employeeId) {
        // Powiadomienie dla NOWEJ stylistki (która otrzymała wizytę)
        await sendPushNotification(
            after.employeeId,
            'Nowa wizyta! 🔄',
            'Wizyta innej stylistki została przypisana do Ciebie.'
        );

        // Powiadomienie dla STAREJ stylistki (żeby wiedziała, dlaczego zniknęło)
        await sendPushNotification(
            before.employeeId,
            'Wizyta przeniesiona ℹ️',
            'Twoja wizyta została przekazana innej stylistce.'
        );
    }
    // Sytuacja A2: Zmieniła się data lub godzina (ale stylistka zostaje ta sama)
    else if (before.date !== after.date || before.time !== after.time) {
        await sendPushNotification(
            after.employeeId,
            'Zmiana terminu 📅',
            `Wizyta przesunięta na ${after.date}, godz. ${after.time}.`
        );
    }

    // Sytuacja B: Klientka właśnie wystawiła ocenę (isRated zmieniło się z false na true)
    if (before.isRated === false && after.isRated === true) {
        const rating = after.rating || 5;
        await sendPushNotification(
            after.employeeId,
            'Nowa opinia! ⭐',
            `Otrzymałaś ocenę ${rating}/5 za ostatnią usługę.`
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
            `Twój salon odwołał wizytę z dnia ${data.date} (${data.time}).`
        );
    }
});