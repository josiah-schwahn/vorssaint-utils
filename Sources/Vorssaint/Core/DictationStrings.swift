// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Strings for hold-to-talk dictation. Same contract as the other
/// FeatureStrings structs: memberwise init with labeled arguments in
/// declaration order, one static per language, all in this file.
struct DictationStrings {
    let pageTitle: String
    let enable: String
    let enableCaption: String
    let systemDictationOff: String
    let openKeyboardSettings: String
    let listening: String
    let transcribing: String
    let turnOnSystemDictation: String
    let failed: String
}

extension FeatureStrings {
    static func dictation(_ language: AppLanguage) -> DictationStrings {
        switch language {
        case .enUS: return .enUS
        case .ptBR: return .ptBR
        case .tr: return .tr
        case .ru: return .ru
        case .es: return .es
        case .sk: return .sk
        case .de: return .de
        case .fr: return .fr
        case .it: return .it
        case .ja: return .ja
        case .ko: return .ko
        case .zhHans: return .zhHans
        case .zhTW: return .zhTW
        case .zhHK: return .zhHK
        case .uk: return .uk
        }
    }
}

extension DictationStrings {
    static let enUS = DictationStrings(
        pageTitle: "Dictation",
        enable: "Dictate with Right Option",
        enableCaption: "Hold Right Option, speak, then let go: what you said is typed where the cursor is. Speech is recognized on this Mac.",
        systemDictationOff: "macOS Dictation is off. Speech recognition only works while it is on.",
        openKeyboardSettings: "Open Keyboard Settings",
        listening: "Listening…",
        transcribing: "Transcribing…",
        turnOnSystemDictation: "Turn on Dictation in Settings",
        failed: "Dictation failed"
    )

    static let ptBR = DictationStrings(
        pageTitle: "Ditado",
        enable: "Ditar com o Option direito",
        enableCaption: "Segure o Option direito, fale e solte: o que você disse é digitado onde está o cursor. A fala é reconhecida neste Mac.",
        systemDictationOff: "O Ditado do macOS está desativado. O reconhecimento de fala só funciona com ele ativado.",
        openKeyboardSettings: "Abrir Ajustes de Teclado",
        listening: "Ouvindo…",
        transcribing: "Transcrevendo…",
        turnOnSystemDictation: "Ative o Ditado nos Ajustes",
        failed: "Falha no ditado"
    )

    static let tr = DictationStrings(
        pageTitle: "Dikte",
        enable: "Sağ Option ile dikte et",
        enableCaption: "Sağ Option tuşunu basılı tutun, konuşun ve bırakın: söyledikleriniz imlecin olduğu yere yazılır. Konuşma bu Mac’te tanınır.",
        systemDictationOff: "macOS Dikte kapalı. Konuşma tanıma yalnızca açıkken çalışır.",
        openKeyboardSettings: "Klavye Ayarları’nı Aç",
        listening: "Dinleniyor…",
        transcribing: "Yazıya dökülüyor…",
        turnOnSystemDictation: "Ayarlar’da Dikte’yi açın",
        failed: "Dikte başarısız oldu"
    )

    static let ru = DictationStrings(
        pageTitle: "Диктовка",
        enable: "Диктовать правой клавишей Option",
        enableCaption: "Удерживайте правую клавишу Option, говорите и отпустите: сказанное будет напечатано там, где стоит курсор. Речь распознаётся на этом Mac.",
        systemDictationOff: "Диктовка macOS выключена. Распознавание речи работает, только когда она включена.",
        openKeyboardSettings: "Открыть настройки клавиатуры",
        listening: "Слушаю…",
        transcribing: "Расшифровка…",
        turnOnSystemDictation: "Включите диктовку в Настройках",
        failed: "Не удалось распознать речь"
    )

    static let es = DictationStrings(
        pageTitle: "Dictado",
        enable: "Dictar con la tecla Opción derecha",
        enableCaption: "Mantén pulsada la tecla Opción derecha, habla y suéltala: lo que dijiste se escribe donde está el cursor. La voz se reconoce en este Mac.",
        systemDictationOff: "El Dictado de macOS está desactivado. El reconocimiento de voz solo funciona mientras está activado.",
        openKeyboardSettings: "Abrir ajustes de Teclado",
        listening: "Escuchando…",
        transcribing: "Transcribiendo…",
        turnOnSystemDictation: "Activa el Dictado en Ajustes",
        failed: "Error en el dictado"
    )

    static let sk = DictationStrings(
        pageTitle: "Diktovanie",
        enable: "Diktovať pravým klávesom Option",
        enableCaption: "Podržte pravý kláves Option, hovorte a pustite: čo ste povedali, sa napíše tam, kde je kurzor. Reč sa rozpoznáva na tomto Macu.",
        systemDictationOff: "Diktovanie v macOS je vypnuté. Rozpoznávanie reči funguje, len keď je zapnuté.",
        openKeyboardSettings: "Otvoriť nastavenia klávesnice",
        listening: "Počúvam…",
        transcribing: "Prepisujem…",
        turnOnSystemDictation: "Zapnite Diktovanie v Nastaveniach",
        failed: "Diktovanie zlyhalo"
    )

    static let de = DictationStrings(
        pageTitle: "Diktat",
        enable: "Mit der rechten Wahltaste diktieren",
        enableCaption: "Rechte Wahltaste gedrückt halten, sprechen und loslassen: Das Gesagte wird an der Cursorposition eingegeben. Die Sprache wird auf diesem Mac erkannt.",
        systemDictationOff: "Das macOS-Diktat ist ausgeschaltet. Die Spracherkennung funktioniert nur, wenn es eingeschaltet ist.",
        openKeyboardSettings: "Tastatur-Einstellungen öffnen",
        listening: "Hört zu …",
        transcribing: "Wird transkribiert …",
        turnOnSystemDictation: "Diktat in den Einstellungen einschalten",
        failed: "Diktat fehlgeschlagen"
    )

    static let fr = DictationStrings(
        pageTitle: "Dictée",
        enable: "Dicter avec la touche Option droite",
        enableCaption: "Maintenez la touche Option droite, parlez puis relâchez\u{00A0}: vos paroles sont saisies là où se trouve le curseur. La parole est reconnue sur ce Mac.",
        systemDictationOff: "La Dictée de macOS est désactivée. La reconnaissance vocale ne fonctionne que lorsqu’elle est activée.",
        openKeyboardSettings: "Ouvrir les réglages Clavier",
        listening: "Écoute…",
        transcribing: "Transcription…",
        turnOnSystemDictation: "Activez la Dictée dans les Réglages",
        failed: "Échec de la dictée"
    )

    static let it = DictationStrings(
        pageTitle: "Dettatura",
        enable: "Detta con il tasto Opzione destro",
        enableCaption: "Tieni premuto il tasto Opzione destro, parla e rilascia: ciò che hai detto viene scritto dove si trova il cursore. Il parlato viene riconosciuto su questo Mac.",
        systemDictationOff: "La Dettatura di macOS è disattivata. Il riconoscimento vocale funziona solo quando è attiva.",
        openKeyboardSettings: "Apri Impostazioni Tastiera",
        listening: "In ascolto…",
        transcribing: "Trascrizione…",
        turnOnSystemDictation: "Attiva la Dettatura nelle Impostazioni",
        failed: "Dettatura non riuscita"
    )

    static let ja = DictationStrings(
        pageTitle: "音声入力",
        enable: "右Optionキーで音声入力",
        enableCaption: "右Optionキーを押したまま話して離すと、話した内容がカーソル位置に入力されます。音声はこのMac上で認識されます。",
        systemDictationOff: "macOSの音声入力がオフです。音声認識は音声入力がオンのときだけ動作します。",
        openKeyboardSettings: "キーボード設定を開く",
        listening: "聞き取り中…",
        transcribing: "文字起こし中…",
        turnOnSystemDictation: "設定で音声入力をオンにしてください",
        failed: "音声入力に失敗しました"
    )

    static let ko = DictationStrings(
        pageTitle: "받아쓰기",
        enable: "오른쪽 Option 키로 받아쓰기",
        enableCaption: "오른쪽 Option 키를 누른 채 말하고 손을 떼면 말한 내용이 커서 위치에 입력됩니다. 음성은 이 Mac에서 인식됩니다.",
        systemDictationOff: "macOS 받아쓰기가 꺼져 있습니다. 음성 인식은 받아쓰기가 켜져 있을 때만 작동합니다.",
        openKeyboardSettings: "키보드 설정 열기",
        listening: "듣는 중…",
        transcribing: "변환 중…",
        turnOnSystemDictation: "설정에서 받아쓰기를 켜세요",
        failed: "받아쓰기 실패"
    )

    static let zhHans = DictationStrings(
        pageTitle: "听写",
        enable: "用右 Option 键听写",
        enableCaption: "按住右 Option 键说话，松开后，你说的内容会输入到光标所在处。语音在这台 Mac 上识别。",
        systemDictationOff: "macOS 听写已关闭。只有打开时语音识别才能工作。",
        openKeyboardSettings: "打开键盘设置",
        listening: "正在聆听…",
        transcribing: "正在转写…",
        turnOnSystemDictation: "请在设置中打开听写",
        failed: "听写失败"
    )

    static let zhTW = DictationStrings(
        pageTitle: "聽寫",
        enable: "使用右側 Option 鍵聽寫",
        enableCaption: "按住右側 Option 鍵說話，放開後，你說的內容會輸入到游標所在位置。語音會在這台 Mac 上辨識。",
        systemDictationOff: "macOS 聽寫已關閉。只有開啟時語音辨識才能運作。",
        openKeyboardSettings: "打開鍵盤設定",
        listening: "正在聆聽…",
        transcribing: "正在轉寫…",
        turnOnSystemDictation: "請在設定中開啟聽寫",
        failed: "聽寫失敗"
    )

    static let zhHK = DictationStrings(
        pageTitle: "聽寫",
        enable: "使用右邊的 Option 鍵聽寫",
        enableCaption: "按住右邊的 Option 鍵說話，放開後，你說的內容會輸入到游標所在位置。語音會在這部 Mac 上辨識。",
        systemDictationOff: "macOS 聽寫已關閉。只有開啟時語音辨識才能運作。",
        openKeyboardSettings: "打開鍵盤設定",
        listening: "正在聆聽…",
        transcribing: "正在轉寫…",
        turnOnSystemDictation: "請在設定中開啟聽寫",
        failed: "聽寫失敗"
    )

    static let uk = DictationStrings(
        pageTitle: "Диктування",
        enable: "Диктувати правою клавішею Option",
        enableCaption: "Утримуйте праву клавішу Option, говоріть і відпустіть: сказане буде надруковано там, де стоїть курсор. Мовлення розпізнається на цьому Mac.",
        systemDictationOff: "Диктування macOS вимкнено. Розпізнавання мовлення працює, лише коли його ввімкнено.",
        openKeyboardSettings: "Відкрити параметри клавіатури",
        listening: "Слухаю…",
        transcribing: "Розшифровка…",
        turnOnSystemDictation: "Увімкніть диктування в Параметрах",
        failed: "Не вдалося розпізнати мовлення"
    )
}
