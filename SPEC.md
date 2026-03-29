# Poster AR - Flutter Application Specification

## 1. Project Overview

**Project Name:** poster_ar

**Core Functionality:** A Flutter application that uses image recognition to identify posters from the assets folder, allows users to draw over them when recognized, and persists drawings to overlay them on subsequent scans.

## 2. Technology Stack & Choices

- **Framework:** Flutter 3.x
- **Language:** Dart
- **Target Platform:** Android

### Key Dependencies
- `camera` - Camera access and preview
- `google_mlkit_image_labeling` - Image recognition/labeling
- `image` - Image processing for template matching
- `path_provider` - Local file storage
- `shared_preferences` - Simple key-value storage
- `permission_handler` - Runtime permissions

### State Management
- Provider pattern for simplicity and clarity

### Architecture Pattern
- Clean Architecture with 3 layers:
  - **Presentation:** UI widgets, screens
  - **Domain:** Business logic, services
  - **Data:** Storage, repositories

## 3. Feature List

1. **Camera Preview** - Live camera feed with AR overlay capability
2. **Image Recognition** - Detect and identify posters from assets folder using ML Kit
3. **Poster Template Matching** - Compare camera frames with poster images for precise recognition
4. **Drawing Overlay** - Canvas for drawing over recognized posters
5. **Drawing Persistence** - Save drawings per poster using local storage
6. **AR Overlay** - When a poster is re-recognized, display saved drawing overlaid on it
7. **Gallery View** - View all available posters from assets
8. **Clear Drawing** - Option to clear saved drawings

## 4. UI/UX Design Direction

- **Visual Style:** Modern Material Design 3, dark theme optimized for AR viewing
- **Color Scheme:** Dark background (#1A1A2E) with accent colors (primary: #E94560, secondary: #0F3460)
- **Layout Approach:** Single main screen with camera preview, bottom sheet for poster info and controls
- **Key UI Elements:**
  - Full-screen camera preview
  - Floating action buttons for drawing controls
  - Bottom sheet showing recognized poster info
  - Drawing toolbar (colors, brush size, clear, save)
  - Poster gallery in drawer or separate screen
