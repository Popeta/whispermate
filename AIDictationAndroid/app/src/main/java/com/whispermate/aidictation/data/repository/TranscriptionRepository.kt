package com.whispermate.aidictation.data.repository

import com.whispermate.aidictation.data.preferences.AppPreferences
import com.whispermate.aidictation.data.remote.LanguagePostProcessClient
import com.whispermate.aidictation.data.remote.TranscriptionClient
import com.whispermate.aidictation.domain.model.WhisperLanguages
import kotlinx.coroutines.flow.first
import java.io.File
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class TranscriptionRepository @Inject constructor(
    private val appPreferences: AppPreferences
) {
    suspend fun transcribe(
        audioFile: File,
        prompt: String? = null,
        contextRules: String? = null
    ): Result<String> {
        val languages = appPreferences.selectedLanguages.first()
        val multilingual = appPreferences.multilingualEnabled.first()
        val postProcess = appPreferences.postProcessingEnabled.first()

        return when {
            multilingual && languages.size > 1 && postProcess -> {
                val candidates = TranscriptionClient.transcribeForLanguages(audioFile, languages, prompt)
                if (candidates.isEmpty()) return Result.failure(Exception("All transcription calls failed"))
                val namedCandidates = candidates.mapKeys { (code, _) -> WhisperLanguages.getName(code) ?: code }
                val languageNames = languages.mapNotNull { WhisperLanguages.getName(it) }
                Result.success(LanguagePostProcessClient.postProcess(namedCandidates, languageNames, contextRules))
            }
            multilingual && languages.size > 1 -> {
                val candidates = TranscriptionClient.transcribeForLanguages(audioFile, languages, prompt)
                if (candidates.isEmpty()) return Result.failure(Exception("All transcription calls failed"))
                val namedCandidates = candidates.mapKeys { (code, _) -> WhisperLanguages.getName(code) ?: code }
                Result.success(LanguagePostProcessClient.bestCandidate(namedCandidates))
            }
            postProcess -> {
                val raw = TranscriptionClient.transcribe(audioFile, prompt, null)
                    .getOrElse { return Result.failure(it) }
                Result.success(LanguagePostProcessClient.postProcess(mapOf("auto" to raw), listOf("auto"), contextRules))
            }
            else -> TranscriptionClient.transcribe(audioFile, prompt, null)
        }
    }

    suspend fun buildPrompt(): String {
        val dictionary = appPreferences.dictionaryEntries.first()
            .filter { it.isEnabled }
            .map { it.trigger }

        val shortcuts = appPreferences.shortcuts.first()
            .filter { it.isEnabled }
            .map { it.voiceTrigger }

        val parts = mutableListOf<String>()

        if (dictionary.isNotEmpty()) {
            parts.add("Vocabulary hints: ${dictionary.joinToString(", ")}")
        }

        if (shortcuts.isNotEmpty()) {
            parts.add("Common phrases: ${shortcuts.joinToString(", ")}")
        }

        return parts.joinToString(". ")
    }

    suspend fun applyPostProcessing(text: String): String {
        var result = text

        val dictionary = appPreferences.dictionaryEntries.first()
            .filter { it.isEnabled && it.replacement != null }
            .sortedByDescending { it.trigger.length }

        for (entry in dictionary) {
            result = result.replace(entry.trigger, entry.replacement!!, ignoreCase = true)
        }

        val shortcuts = appPreferences.shortcuts.first()
            .filter { it.isEnabled }
            .sortedByDescending { it.voiceTrigger.length }

        for (shortcut in shortcuts) {
            result = result.replace(shortcut.voiceTrigger, shortcut.expansion, ignoreCase = true)
        }

        return result
    }
}
