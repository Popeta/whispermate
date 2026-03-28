package com.whispermate.aidictation.domain.model

data class WhisperLanguage(
    val code: String,
    val englishName: String,
    val nativeName: String
)

object WhisperLanguages {
    val all: List<WhisperLanguage> = listOf(
        WhisperLanguage("af", "Afrikaans", "Afrikaans"),
        WhisperLanguage("ar", "Arabic", "العربية"),
        WhisperLanguage("hy", "Armenian", "Հայերեն"),
        WhisperLanguage("az", "Azerbaijani", "Azərbaycan"),
        WhisperLanguage("be", "Belarusian", "Беларуская"),
        WhisperLanguage("bs", "Bosnian", "Bosanski"),
        WhisperLanguage("bg", "Bulgarian", "Български"),
        WhisperLanguage("ca", "Catalan", "Català"),
        WhisperLanguage("zh", "Chinese", "中文"),
        WhisperLanguage("hr", "Croatian", "Hrvatski"),
        WhisperLanguage("cs", "Czech", "Čeština"),
        WhisperLanguage("da", "Danish", "Dansk"),
        WhisperLanguage("nl", "Dutch", "Nederlands"),
        WhisperLanguage("en", "English", "English"),
        WhisperLanguage("et", "Estonian", "Eesti"),
        WhisperLanguage("fi", "Finnish", "Suomi"),
        WhisperLanguage("fr", "French", "Français"),
        WhisperLanguage("gl", "Galician", "Galego"),
        WhisperLanguage("de", "German", "Deutsch"),
        WhisperLanguage("el", "Greek", "Ελληνικά"),
        WhisperLanguage("he", "Hebrew", "עברית"),
        WhisperLanguage("hi", "Hindi", "हिन्दी"),
        WhisperLanguage("hu", "Hungarian", "Magyar"),
        WhisperLanguage("is", "Icelandic", "Íslenska"),
        WhisperLanguage("id", "Indonesian", "Bahasa Indonesia"),
        WhisperLanguage("it", "Italian", "Italiano"),
        WhisperLanguage("ja", "Japanese", "日本語"),
        WhisperLanguage("kn", "Kannada", "ಕನ್ನಡ"),
        WhisperLanguage("kk", "Kazakh", "Қазақ"),
        WhisperLanguage("ko", "Korean", "한국어"),
        WhisperLanguage("lv", "Latvian", "Latviešu"),
        WhisperLanguage("lt", "Lithuanian", "Lietuvių"),
        WhisperLanguage("mk", "Macedonian", "Македонски"),
        WhisperLanguage("ms", "Malay", "Bahasa Melayu"),
        WhisperLanguage("mr", "Marathi", "मराठी"),
        WhisperLanguage("mi", "Maori", "Te Reo Māori"),
        WhisperLanguage("ne", "Nepali", "नेपाली"),
        WhisperLanguage("no", "Norwegian", "Norsk"),
        WhisperLanguage("fa", "Persian", "فارسی"),
        WhisperLanguage("pl", "Polish", "Polski"),
        WhisperLanguage("pt", "Portuguese", "Português"),
        WhisperLanguage("ro", "Romanian", "Română"),
        WhisperLanguage("ru", "Russian", "Русский"),
        WhisperLanguage("sr", "Serbian", "Српски"),
        WhisperLanguage("sk", "Slovak", "Slovenčina"),
        WhisperLanguage("sl", "Slovenian", "Slovenščina"),
        WhisperLanguage("es", "Spanish", "Español"),
        WhisperLanguage("sw", "Swahili", "Kiswahili"),
        WhisperLanguage("sv", "Swedish", "Svenska"),
        WhisperLanguage("tl", "Tagalog", "Tagalog"),
        WhisperLanguage("ta", "Tamil", "தமிழ்"),
        WhisperLanguage("th", "Thai", "ไทย"),
        WhisperLanguage("tr", "Turkish", "Türkçe"),
        WhisperLanguage("uk", "Ukrainian", "Українська"),
        WhisperLanguage("ur", "Urdu", "اردو"),
        WhisperLanguage("vi", "Vietnamese", "Tiếng Việt"),
        WhisperLanguage("cy", "Welsh", "Cymraeg"),
    )

    private val byCode: Map<String, WhisperLanguage> = all.associateBy { it.code }

    fun getName(code: String): String? = byCode[code]?.englishName

    fun getLanguage(code: String): WhisperLanguage? = byCode[code]
}
