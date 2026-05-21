# Frontend Development Plan

**Goal:** Build the Flutter client matching the provided chat UI references, starting from a stable app skeleton before adding full business behavior.

**Architecture:** Use a feature-first Flutter structure. Keep UI, state, models, and services separated so message lists, group pages, and chat rooms can evolve without becoming one large screen file.

**Tech Stack:** Flutter, Dart, Socket.IO client, Material 3 baseline with custom design tokens. Recommended additions when implementation starts: `go_router` for routing, `flutter_riverpod` for state, `cached_network_image` for avatars/media.

---

## Phase 0: Environment And Project Baseline

- Confirm Flutter SDK is installed and available in PATH.
- Run `flutter create .` inside `frontend` to generate platform files.
- Run `flutter pub get`.
- Add app icons, splash configuration later after UI direction is stable.
- Keep backend URL configurable through `--dart-define=SOCKET_URL=...`.

## Phase 1: Frontend Architecture

- Create feature folders:
  - `features/messages`
  - `features/groups`
  - `features/contacts`
  - `features/profile`
  - `features/chat_room`
  - `features/create_group`
  - `shared/widgets`
  - `shared/theme`
  - `shared/models`
  - `shared/services`
- Add routing table for:
  - message home
  - group list
  - chat room
  - group detail
  - create group
  - contacts
  - profile
- Define app-level state ownership before wiring real APIs.

## Phase 2: Design System

- Create color tokens for the blue header gradient, surface whites, dividers, text grays, badges, and online status.
- Create typography tokens for page titles, list titles, secondary text, timestamps, and message bubbles.
- Build reusable UI components:
  - status bar spacer / phone-safe scaffold
  - blue curved header
  - search bar
  - segmented tab control
  - avatar and group avatar grid
  - unread badge
  - bottom navigation
  - action icon button
  - settings row and switch row

## Phase 3: Static Screen Rebuilds

- Rebuild message home screen from reference image 1.
- Rebuild group list screen from reference image 4.
- Rebuild create group member picker from reference image 5.
- Rebuild group chat room from reference image 3.
- Rebuild group detail screen from reference image 2.
- Use local mock data first, no backend dependency in this phase.

## Phase 4: Navigation Flow

- Bottom navigation switches between messages, contacts, groups, and profile.
- Message list item opens chat room.
- Group list item opens group detail or chat room depending on tap target.
- Chat room menu opens group detail.
- Group creation flow opens from the plus button.
- Create group page proceeds to group naming/confirmation placeholder.

## Phase 5: State And Data Models

- Define frontend models:
  - `User`
  - `Conversation`
  - `Group`
  - `GroupMember`
  - `ChatMessage`
  - `Attachment`
  - `UnreadCounter`
- Add repositories with mock implementations first.
- Keep Socket.IO service behind an interface so mock UI and real backend can swap cleanly.

## Phase 6: Socket.IO Integration

- Connect chat room to backend Socket.IO gateway.
- Join room on page open.
- Load `room:history`.
- Send `message:send`.
- Listen for `message:new`.
- Show connection states: connecting, connected, reconnecting, failed.
- Add basic optimistic sending once backend message shape is final.

## Phase 7: File And Rich Message UI

- Add UI cards for file messages, image messages, system task cards, mentions, and reactions.
- Keep upload behavior behind a service abstraction.
- Later connect to MinIO/OSS upload endpoint once backend file API exists.

## Phase 8: Interaction Details

- Pull to refresh conversation list.
- Long press message actions placeholder.
- Search input states.
- Empty states.
- Loading skeletons.
- Offline/retry banners.
- Mute, pin, save-to-contacts switches on group detail page.

## Phase 9: Testing And Verification

- Widget tests for reusable components.
- Widget tests for each page with mock data.
- Service tests for Socket.IO event mapping where practical.
- Manual visual verification on iPhone-sized and Android-sized viewports.
- Check text overflow for Chinese names, long group names, long messages, and unread badges.

## Phase 10: Delivery Order

1. Flutter SDK baseline and package setup.
2. Theme and shared widgets.
3. Static message home.
4. Static group list and group detail.
5. Static chat room.
6. Static create group flow.
7. Routing between pages.
8. Mock repositories and state management.
9. Socket.IO integration.
10. File/rich message placeholders.
11. Visual polish and tests.

