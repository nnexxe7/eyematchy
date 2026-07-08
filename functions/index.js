const { onDocumentCreated, onDocumentUpdated, onDocumentDeleted } = require("firebase-functions/v2/firestore");
const { onTaskDispatched } = require("firebase-functions/v2/tasks"); // 🚀 NOWY IMPORT ZADAŃ
const admin = require('firebase-admin');
const { getFunctions } = require("firebase-admin/functions");

admin.initializeApp();

// ---------------------------------------------------------------------
// 1. FUNKCJE POMOCNICZE
// ---------------------------------------------------------------------

async function sendPushNotification(userId, title, body) {
    if (!userId) return;
    try {
        const userDoc = await admin.firestore().collection('users').doc(userId).get();
        if (!userDoc.exists) return;

        const fcmToken = userDoc.data().fcmToken;
        if (!fcmToken) {
            console.log(`Brak tokena FCM dla użytkownika: ${userId}`);
            return;
        }

        const message = {
            notification: { title, body },
            android: { notification: { channelId: "high_importance_channel", priority: "max", sound: "default" } },
            token: fcmToken
        };
        await admin.messaging().send(message);
        console.log(`Wysłano: "${title}" do ${userId}`);
    } catch (error) {
        console.error('Błąd wysyłania powiadomienia:', error);
    }
}

// Funkcja obliczająca czas uruchomienia przypomnienia
async function scheduleReminders(appointmentId, data) {
    if (data.isBlock || !data.clientId) return;

    // Przekształcamy stringi z aplikacji na obiekt daty dla serwera
    const [year, month, day] = data.date.split('-');
    const [hour, minute] = data.time.split(':');

    // Tworzymy docelową datę wizyty (Zakładamy czas polski, Cloud Functions zazwyczaj działają w UTC,
    // odejmujemy 2 godziny dla bezpieczeństwa strefy czasowej, żeby przypomnienia nie przychodziły z opóźnieniem).
    const appTime = new Date(`${year}-${month}-${day}T${hour}:${minute}:00`);
    appTime.setHours(appTime.getHours() - 2);

    const now = new Date();

    // Obliczamy daty przypomnień
    const time24hBefore = new Date(appTime.getTime() - (24 * 60 * 60 * 1000));
    const time1hBefore = new Date(appTime.getTime() - (1 * 60 * 60 * 1000));

    // Inicjalizujemy kolejkę zadań Google Cloud Tasks
    const queue = getFunctions().taskQueue("sendReminderTask");

    // Jeśli do wizyty zostało więcej niż 24h, planujemy zadanie na jutro
    if (time24hBefore > now) {
        await queue.enqueue({
            appointmentId: appointmentId,
            type: '24h',
            originalDate: data.date,
            originalTime: data.time
        }, { scheduleTime: time24hBefore });
        console.log(`Zaplanowano przypomnienie 24h dla wizyty ${appointmentId}`);
    }

    // Jeśli do wizyty zostało więcej niż 1h, planujemy przypomnienie godzinne
    if (time1hBefore > now) {
        await queue.enqueue({
            appointmentId: appointmentId,
            type: '1h',
            originalDate: data.date,
            originalTime: data.time
        }, { scheduleTime: time1hBefore });
        console.log(`Zaplanowano przypomnienie 1h dla wizyty ${appointmentId}`);
    }
}


// ---------------------------------------------------------------------
// 2. ROBOT WYSYŁAJĄCY PRZYPOMNIENIA (BUDZI SIĘ TYLKO O KONKRETNEJ GODZINIE)
// ---------------------------------------------------------------------

exports.sendReminderTask = onTaskDispatched(async (req) => {
    const { appointmentId, type, originalDate, originalTime } = req.data;

    // Gdy budzik zadzwoni, sprawdzamy bazę (1 odczyt), aby upewnić się, że wizyta wciąż istnieje
    const doc = await admin.firestore().collection('appointments').doc(appointmentId).get();

    if (!doc.exists) {
        console.log("Wizyta została usunięta. Anuluję wysyłanie przypomnienia.");
        return;
    }

    const data = doc.data();

    // 🚀 GENIALNY MECHANIZM: Jeśli stylistka zmieniła datę/godzinę, dane w bazie
    // będą inne niż w oryginalnym zadaniu. W takim wypadku stary budzik po prostu się wyłącza!
    // (Nowy budzik został już utworzony w onDocumentUpdated).
    if (data.date !== originalDate || data.time !== originalTime) {
        console.log("Termin wizyty został zmieniony. Stare zadanie Cloud Task zostaje anulowane.");
        return;
    }

    if (type === '24h' && !data.notified24h) {
        await sendPushNotification(data.clientId, 'Przypomnienie o wizycie 📅', `Już jutro o ${data.time} masz wizytę w salonie ${data.salonName} na zabieg ${data.serviceName}!`);
        await doc.ref.update({ notified24h: true });
    }
    else if (type === '1h' && !data.notified1h) {
        await sendPushNotification(data.clientId, 'To już niedługo! ⏰', `Twoja wizyta w salonie ${data.salonName} zaczyna się za godzinę (o ${data.time}). Do zobaczenia!`);
        await doc.ref.update({ notified1h: true });
    }
});


// ---------------------------------------------------------------------
// 3. OBSŁUGA BAZY DANYCH (WYZWALACZE)
// ---------------------------------------------------------------------

exports.sendAppointmentNotification = onDocumentCreated("appointments/{appointmentId}", async (event) => {
    const data = event.data.data();
    const appointmentId = event.params.appointmentId;

    if (data.isBlock === true) return null;

    // Wysyłamy powiadomienie do stylistki o nowej rezerwacji
    await sendPushNotification(
        data.employeeId,
        'Nowa rezerwacja! 🎉',
        `${data.clientName} zapisał(a) się na ${data.serviceName} (${data.date} o godz. ${data.time}).`
    );

    // 🚀 Planujemy przypomnienia w chmurze!
    await scheduleReminders(appointmentId, data);
});


exports.updateAppointmentNotification = onDocumentUpdated("appointments/{appointmentId}", async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    const appointmentId = event.params.appointmentId;

    if (after.isBlock === true || before.isBlock === true) return null;

    if (before.employeeId !== after.employeeId) {
        await sendPushNotification(after.employeeId, 'Nowa wizyta! 🔄', 'Wizyta innej stylistki została przypisana do Ciebie.');
        await sendPushNotification(before.employeeId, 'Wizyta przeniesiona ℹ️', 'Twoja wizyta została przekazana innej stylistce.');
    }
    else if (before.date !== after.date || before.time !== after.time) {
        await sendPushNotification(after.employeeId, 'Zmiana terminu 📅', `Wizyta przesunięta na ${after.date}, godz. ${after.time}.`);
        if (after.clientId) {
            await sendPushNotification(after.clientId, 'Zmiana terminu wizyty 📅', `Twój salon przesunął wizytę na ${after.date} na godzinę ${after.time}.`);
        }

        // 🚀 Jeśli zmieniono datę lub godzinę, planujemy nowe przypomnienia w chmurze!
        // (Stare same się zneutralizują dzięki naszemu sprawdzaniu originalDate)
        await scheduleReminders(appointmentId, after);
    }

    if (before.isRated === false && after.isRated === true) {
        const rating = after.rating || 5;
        await sendPushNotification(after.employeeId, 'Nowa opinia! ⭐', `Otrzymałaś ocenę ${rating}/5 za ostatnią usługę.`);
    }
});


exports.deleteAppointmentNotification = onDocumentDeleted("appointments/{appointmentId}", async (event) => {
    const data = event.data.data();

    if (data.isBlock === true) return null;

    if (data.clientId) {
        await sendPushNotification(data.clientId, 'Wizyta odwołana ❌', `Twój salon odwołał wizytę z dnia ${data.date} (${data.time}).`);
    }
});