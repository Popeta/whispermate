package com.whispermate.aidictation.ui.screens.settings

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.MenuAnchorType
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.whispermate.aidictation.R
import com.whispermate.aidictation.data.preferences.ApiProvider

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ApiConfigScreen(
    onNavigateBack: () -> Unit,
    viewModel: ApiConfigViewModel = hiltViewModel()
) {
    val state by viewModel.uiState.collectAsState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.settings_api_config)) },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = stringResource(R.string.back)
                        )
                    }
                }
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(paddingValues)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(24.dp)
        ) {
            ApiSectionCard(
                title = stringResource(R.string.api_config_transcription),
                provider = state.transcriptionProvider,
                apiKey = state.transcriptionApiKey,
                model = state.transcriptionModel,
                models = state.transcriptionModels,
                isLoadingModels = state.isLoadingTranscriptionModels,
                onProviderChange = viewModel::setTranscriptionProvider,
                onApiKeyChange = viewModel::setTranscriptionApiKey,
                onModelChange = viewModel::setTranscriptionModel
            )

            ApiSectionCard(
                title = stringResource(R.string.api_config_postprocessing),
                provider = state.postProcessingProvider,
                apiKey = state.postProcessingApiKey,
                model = state.postProcessingModel,
                models = state.postProcessingModels,
                isLoadingModels = state.isLoadingPostProcessingModels,
                onProviderChange = viewModel::setPostProcessingProvider,
                onApiKeyChange = viewModel::setPostProcessingApiKey,
                onModelChange = viewModel::setPostProcessingModel
            )

            Button(
                onClick = viewModel::resetToDefaults,
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(
                    containerColor = MaterialTheme.colorScheme.errorContainer,
                    contentColor = MaterialTheme.colorScheme.onErrorContainer
                )
            ) {
                Text(stringResource(R.string.api_config_reset))
            }

            Spacer(modifier = Modifier.height(8.dp))
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ApiSectionCard(
    title: String,
    provider: ApiProvider,
    apiKey: String,
    model: String,
    models: List<String>,
    isLoadingModels: Boolean,
    onProviderChange: (ApiProvider) -> Unit,
    onApiKeyChange: (String) -> Unit,
    onModelChange: (String) -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Text(
                text = title,
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.primary
            )

            // Provider dropdown
            ProviderDropdown(
                selected = provider,
                onSelect = onProviderChange
            )

            // API key field
            ApiKeyField(
                value = apiKey,
                onValueChange = onApiKeyChange
            )

            // Model dropdown
            ModelDropdown(
                selected = model,
                models = models,
                isLoading = isLoadingModels,
                onSelect = onModelChange
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ProviderDropdown(
    selected: ApiProvider,
    onSelect: (ApiProvider) -> Unit
) {
    var expanded by remember { mutableStateOf(false) }

    ExposedDropdownMenuBox(
        expanded = expanded,
        onExpandedChange = { expanded = it }
    ) {
        OutlinedTextField(
            value = selected.displayName,
            onValueChange = {},
            readOnly = true,
            label = { Text(stringResource(R.string.api_config_provider)) },
            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
            modifier = Modifier
                .fillMaxWidth()
                .menuAnchor(type = MenuAnchorType.PrimaryNotEditable)
        )
        ExposedDropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false }
        ) {
            ApiProvider.entries.forEach { provider ->
                DropdownMenuItem(
                    text = { Text(provider.displayName) },
                    onClick = {
                        onSelect(provider)
                        expanded = false
                    },
                    contentPadding = ExposedDropdownMenuDefaults.ItemContentPadding
                )
            }
        }
    }
}

@Composable
private fun ApiKeyField(
    value: String,
    onValueChange: (String) -> Unit
) {
    var passwordVisible by remember { mutableStateOf(false) }

    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        label = { Text(stringResource(R.string.api_config_api_key)) },
        placeholder = { Text(stringResource(R.string.api_config_key_placeholder)) },
        visualTransformation = if (passwordVisible) VisualTransformation.None else PasswordVisualTransformation(),
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
        trailingIcon = {
            IconButton(onClick = { passwordVisible = !passwordVisible }) {
                Icon(
                    imageVector = if (passwordVisible) Icons.Default.VisibilityOff else Icons.Default.Visibility,
                    contentDescription = if (passwordVisible) "Hide key" else "Show key"
                )
            }
        },
        singleLine = true,
        modifier = Modifier.fillMaxWidth()
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ModelDropdown(
    selected: String,
    models: List<String>,
    isLoading: Boolean,
    onSelect: (String) -> Unit
) {
    var expanded by remember { mutableStateOf(false) }

    ExposedDropdownMenuBox(
        expanded = expanded && models.isNotEmpty(),
        onExpandedChange = { if (models.isNotEmpty()) expanded = it }
    ) {
        OutlinedTextField(
            value = selected,
            onValueChange = {},
            readOnly = true,
            label = { Text(stringResource(R.string.api_config_model)) },
            placeholder = { if (isLoading) Text(stringResource(R.string.api_config_loading_models)) },
            trailingIcon = {
                if (isLoading) {
                    Box(modifier = Modifier.padding(12.dp)) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(20.dp),
                            strokeWidth = 2.dp
                        )
                    }
                } else {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded)
                    }
                }
            },
            modifier = Modifier
                .fillMaxWidth()
                .menuAnchor(type = MenuAnchorType.PrimaryNotEditable),
            enabled = !isLoading && models.isNotEmpty()
        )
        ExposedDropdownMenu(
            expanded = expanded && models.isNotEmpty(),
            onDismissRequest = { expanded = false }
        ) {
            models.forEach { modelId ->
                DropdownMenuItem(
                    text = { Text(modelId, style = MaterialTheme.typography.bodyMedium) },
                    onClick = {
                        onSelect(modelId)
                        expanded = false
                    },
                    contentPadding = ExposedDropdownMenuDefaults.ItemContentPadding
                )
            }
        }
    }
}
