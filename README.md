# ThForu — Multi-Provider AI Chat App

A Flutter cross-platform AI chat application supporting multiple AI providers, expert panel orchestration, tool calling, deep search, GitHub repository analysis, and a sandbox terminal — all in one app.

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.44-blue" alt="Flutter 3.44">
  <img src="https://img.shields.io/badge/Dart-3.2+-blue" alt="Dart 3.2+">
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20Windows-brightgreen" alt="Platform">
  <img src="https://img.shields.io/badge/Version-1.2.0-blue" alt="Version 1.2.0">
</p>

---

## Features

### Core Chat
- **Multi-Provider** — DeepSeek, Qwen3 (Tongyi Qianwen), OpenAI GPT-4.1, Xiaomi MiMo, and any OpenAI-compatible API
- **Streaming SSE** — Real-time token-by-token response with smooth UI updates (80ms throttle)
- **Vision** — Image input with base64 encoding for compatible models
- **File Attachments** — Text files auto-injected into prompt context; binary files reported with metadata
- **Voice Input** — Record audio and transcribe to text
- **Quote Reply** — WeChat-style reply with grey reference bar and tap-to-scroll

### Expert Panel (Multi-Agent Orchestration)
- Configure a panel of AI experts (each with its own provider/model)
- All experts answer the same question **concurrently**
- A **gateway AI** synthesizes all responses into a final comprehensive answer
- Live status tracking per expert (pending → streaming → completed/failed)

### Deep Search
- AI automatically **decomposes** complex questions into sub-queries
- DuckDuckGo search across all sub-queries
- Concurrent page fetching with rate limiting
- AI synthesizes a structured report with **sources cited**

### Tool Calling (Function Calling)
AI can autonomously use these tools during conversation:

| Tool | Description |
|---|---|
| **Terminal** | Execute sandboxed shell commands (cd, pwd, ls, cat, mkdir, touch, write, append, rm, clear) |
| **Web Search** | Search the web via DuckDuckGo (no API key needed) |
| **Memory** | Persistent key-value memory across conversations (save/get/list/delete/search) |
| **DateTime** | Get current date and time |

**Safety**: Terminal runs in strict sandbox mode with command whitelist, permission tiers (read-only / write / delete), and dangerous-pattern blacklist.

### Skills (Custom System Prompts)
- Define **trigger keywords** that auto-activate a custom system prompt
- Per-skill **tool whitelist** — restrict which tools the AI can access
- Automatic matching: the skill with the highest keyword score wins

### Personas
- Create custom AI personas with name, avatar, and system prompt
- Assign a persona to any conversation

### Desktop Companion
- Floating draggable character (default: "Han Li" 韩立, cultivation-novel style) on the chat screen
- Double-tap to dock to nearest edge
- Configurable size, colors, and visibility

### GitHub Repository Explorer
- Browse public (anonymous) or private (token) repositories
- **File tree** with expandable folders and file preview
- **Code viewer** with syntax highlighting
- **Agent mode**: AI selects relevant files, reads code, and answers questions
- Cross-repository file references with `@repo/file` shortcuts
- Chat history persisted (up to 50 entries)

### Sandbox Terminal
- Interactive terminal tab with command history (up/down arrow)
- Built-in commands for file operations
- Configurable permissions per session

### Memory System
- AI can save important facts about the user across conversations
- Automatic memory injection: relevant memories loaded at the start of each chat
- Full CRUD management in Memory screen

### Additional Features
- **Favorites** — bookmark messages; view all favorites with source conversation links
- **Full-text Search** — search across all conversations and messages (with keyword highlighting)
- **Custom Wallpaper** — per-conversation background images
- **Material 3 Theming** — 13 seed colors + light/dark mode
- **Message Actions** — long-press for copy / quote reply / favorite / delete
- **Multi-select** — batch delete messages
- **Export to DOCX** — generate Word documents from conversations (pure Dart, no external deps)
- **LaTeX Rendering** — inline (`$...$`) and block (`$$...$$`) math formulas via `flutter_math_fork`
- **SVG Rendering** — inline SVG with fullscreen zoom viewer
- **Markdown Tables** — auto-width columns, horizontal scroll, fullscreen zoom
- **Code Blocks** — horizontal scroll + copy button + fullscreen zoom
- **Reply Context** — quoted reply preview injected as system prompt for better answers

---

## Architecture

```
lib/
├── main.dart                            # Entry point: SQLite init, DB migration
├── app.dart                             # MaterialApp, routing, theme
├── db/
│   ├── database_helper.dart             # SQLite (v2): conversations, messages, memories
│   ├── conversation_dao.dart            # Conversation CRUD
│   ├── message_dao.dart                 # Message CRUD + search + favorites
│   └── memory_dao.dart                  # Memory CRUD + relevance search
├── models/
│   ├── message.dart                     # Message: text, images, files, tool_calls, OpenAI serialization
│   ├── conversation.dart                # Conversation: provider, model, persona, expert panel
│   ├── provider_config.dart             # AI provider config + 4 built-in presets
│   ├── persona.dart                     # Persona: name, system prompt, avatar
│   ├── expert_panel.dart                # Expert panel: experts + gateway
│   ├── skill.dart                       # Skill: keywords, system prompt, tool whitelist
│   ├── companion_config.dart            # Desktop companion settings
│   └── tool_settings.dart               # Tool enable/disable settings
├── services/
│   ├── ai_service.dart                  # OpenAI-compatible API client (stream + non-stream + tools)
│   ├── expert_mode_service.dart         # Concurrent expert queries + synthesis prompt builder
│   ├── deep_search_service.dart         # Query decomposition → search → fetch → synthesize pipeline
│   ├── search_service.dart              # DuckDuckGo HTML scraper + page content extractor
│   ├── skill_matcher.dart               # Keyword-based skill matching algorithm
│   ├── token_counter.dart               # Character-level token estimation (Chinese-aware)
│   ├── word_generator.dart              # Pure-Dart DOCX generator (XML + ZIP)
│   ├── audio_service.dart               # Voice recording + transcription
│   ├── image_service.dart               # Image pick/crop/compress/save
│   ├── github_service.dart              # GitHub REST API wrapper
│   └── terminal/
│       ├── terminal_policy.dart         # Security policy: mode, permissions, blocked patterns
│       └── terminal_runner.dart         # Sandbox command execution engine
├── tools/
│   ├── tool_definition.dart             # Tool schema + ToolCall + ToolResult types
│   ├── tool_registry.dart               # Tool registry: enable/disable + OpenAI format conversion
│   ├── tool_executor.dart               # Tool dispatch: route calls to correct executor
│   ├── terminal_tool.dart               # Sandbox terminal tool
│   ├── web_search_tool.dart             # Web search tool (DuckDuckGo)
│   ├── memory_tool.dart                 # Persistent memory CRUD tool
│   └── datetime_tool.dart               # Date/time tool
├── state/
│   ├── providers.dart                   # All Riverpod providers (single source of truth)
│   ├── chat_state.dart                  # ChatState: messages, streaming, expert phase, tool executions
│   ├── chat_notifier.dart               # Core chat logic: normal/expert/tool-calling/deep-search flows
│   ├── provider_list_notifier.dart      # AI provider CRUD
│   ├── conversation_list_notifier.dart  # Conversation list + search
│   ├── expert_panel_list_notifier.dart  # Expert panel CRUD
│   ├── persona_list_notifier.dart       # Persona CRUD
│   ├── skill_list_notifier.dart         # Skill CRUD
│   ├── theme_notifier.dart              # Theme color + mode persistence
│   ├── formula_display_notifier.dart    # LaTeX display mode
│   ├── terminal_notifier.dart           # Terminal session state
│   ├── terminal_state.dart              # Terminal state types
│   ├── tool_settings_notifier.dart      # Tool enable/disable + terminal permissions
│   └── companion_config_notifier.dart   # Companion settings
├── screens/
│   ├── main_screen.dart                 # Bottom nav: Chats / Skills / Terminal / GitHub
│   ├── chat_screen.dart                 # Core chat UI: bubble list, input, companion, search, multi-select
│   ├── conversations_screen.dart        # Conversation list: search, pin, delete
│   ├── settings_screen.dart             # Theme/providers/panels/personas/companion/tools
│   ├── skills_screen.dart               # Skill management
│   ├── favorites_screen.dart            # Favorite messages (RouteAware refresh)
│   ├── memory_screen.dart               # Memory management
│   ├── terminal_screen.dart             # Interactive sandbox terminal
│   └── github_screen.dart               # GitHub repo browser + agent chat
└── widgets/
    ├── message_bubble.dart              # Chat bubble: markdown, math, actions, quote reply
    ├── chat_input_bar.dart              # Input bar: text, images, files, voice, deep search
    ├── math_markdown.dart               # Core: Markdown + LaTeX + SVG hybrid renderer
    ├── streaming_cursor.dart            # Blinking cursor during streaming
    ├── typing_indicator.dart            # Three-dot jumping animation
    ├── svg_block.dart                   # SVG renderer with fullscreen zoom
    ├── formula_viewer.dart              # Fullscreen formula viewer
    ├── conversation_tile.dart           # Conversation list item
    ├── expert_progress_widget.dart      # Expert mode progress indicator
    ├── tool_execution_widget.dart       # Tool call result display
    ├── assistant_avatar.dart            # AI avatar with persona support
    ├── companion_character.dart         # Draggable desktop companion
    ├── provider_form_dialog.dart        # Add/edit provider dialog
    ├── expert_panel_form_dialog.dart    # Add/edit expert panel dialog
    ├── persona_form_dialog.dart         # Add/edit persona dialog
    ├── skill_form_dialog.dart           # Add/edit skill dialog
    └── image_preview_sheet.dart         # Image preview bottom sheet
```

### State Management (Riverpod)

All state is managed through Riverpod with `StateNotifier`:

- **`chatProvider(conversationId)`** — `.family` provider, one per conversation, kept alive
- **Provider lists** — `providerListProvider`, `conversationListProvider`, `skillListProvider`, `personaListProvider`, `expertPanelListProvider`
- **Resolved providers** — `resolvedExpertPanelProvider(panelId)` resolves panel IDs to concrete AI provider objects
- **Settings** — `themeProvider`, `toolSettingsProvider`, `companionConfigProvider`, `terminalProvider`, `formulaDisplayProvider`

### Database (SQLite)

- **Version**: 2
- **Tables**: `conversations`, `messages`, `memories`
- **Migration**: Auto-migrates from legacy SharedPreferences storage on first launch
- **Foreign keys**: Enabled with cascading delete (conversation → messages)

### Chat Flow

```
User Input
  → Validate API config
  → Create user + assistant messages → DB
  → Build context stack:
      1. Persona system prompt (if assigned)
      2. Relevant memories (auto-injected)
      3. Reply context (if quoting)
      4. Skill system prompt (if keyword-matched)
      5. Token trimming (~4000 token budget)
  → Route:
      ├─ Tool Calling: chatWithTools() → up to 5 tool-call rounds
      ├─ Expert Panel: parallel experts → gateway synthesis
      ├─ Deep Search: decompose → search → fetch → synthesize
      └─ Normal: SSE streaming → 80ms UI / 2s DB throttling
  → Wakelock released, conversation time updated
```

---

## Quick Start

### Prerequisites

- Flutter SDK 3.2+
- Android Studio (for Android builds)
- Visual Studio 2022 (for Windows builds)

### Install

```bash
git clone https://github.com/gs666777/ThForu.git
cd ThForu
flutter pub get
```

### Run

```bash
# Android
flutter run -d android

# Windows
flutter run -d windows
```

### Build

```bash
# Android APK
flutter build apk --release --no-tree-shake-icons

# Windows
flutter build windows --release
```

---

## API Configuration

ThForu works with any **OpenAI Chat Completions API**-compatible service. Built-in presets:

| Provider | Model | Features |
|---|---|---|
| **DeepSeek** | deepseek-chat / deepseek-reasoner | Reasoning effort |
| **Qwen3 Max** | qwen3-max / qwen3-vl-max / qwen3-coder | Vision |
| **OpenAI GPT-4.1** | gpt-4.1 / gpt-4o / o4-mini / o3 | Vision, Tools |
| **Xiaomi MiMo** | mimo-v2.5 / mimo-v2-omni | Vision, Files |

Custom providers can be added with any base URL and API key. Supports custom headers for alternative auth schemes.

---

## Known Limitations

- `flutter_math_fork` does not support some advanced LaTeX commands (`\mathbb`, `\mathcal`)
- `flutter_markdown` is discontinued (upstream replacement: `flutter_markdown_plus`)
- Windows debug mode triggers a `LayoutBuilder` assertion with `Math.tex` + `IntrinsicColumnWidth` (release mode unaffected)
- AGP 8.9.1 / Kotlin 2.1.20 have deprecation warnings (will need updating for future Flutter versions)
- GitHub API anonymous access limited to 60 requests/hour
- Deep search uses DuckDuckGo HTML parsing, which may be region-restricted
- Tree-shaking icons requires `--no-tree-shake-icons` due to dynamic `IconData` usage from DB-stored personas
- Audio transcription endpoint is currently unimplemented (stub)

---

## License

MIT
