# Color Design Pattern

This document outlines the color system used in the application, designed for a professional multi-tenant ticketing system.

## 🎨 Core Palette

### Primary Color: Navy Blue
Used for main actions, headers, and branding. Represents trust and professionalism.
```javascript
colors: {
    primary: {
        600: '#1E3A8A',
        500: '#2563EB',
        400: '#60A5FA',
        100: '#DBEAFE',
        50: '#EFF6FF',
    },
}

### Accent Color: Teal
Used for highlights, secondary buttons, and visual interest. Adds a modern, approachable touch.
colors: {
    accent: {
        700: '#0F766E',
        600: '#0D9488',
        500: '#14B8A6',
        400: '#2DD4BF',
        300: '#5EEAD4',
    },
}

## 🚦 Status Colors

### Success (Green)
Used for completion messages, success states, and positive trends.
colors: {
    success: {
        700: '#047857',
        500: '#10B981',
        100: '#DCFCE7',
    },
}

### Warning (Amber)
Used for alerts, pending states, and cautions.
colors: {
    warning: {
        700: '#B45309',
        500: '#F59E0B',
    },
}

### Error (Red)
Used for destructive actions, error messages, and critical alerts.
colors: {
    error: {
        700: '#B91C1C',
        500: '#EF4444',
        100: '#FEF3C7'
    },
}

## 🌑 Neutrals & Secondary

Used for text, backgrounds, borders, and structural elements.

### Secondary (Slate)
colors: {
    secondary: {
        900: '#0F172A',
        600: '#475569',
        500: '#64748B',
        200: '#E2E8F0',
        100: '#F1F5F9',
    },
}

### Neutral
colors: {
    neutral: {
        white: '#FFFFFF',
        50: '#F8FAFC',
        100: '#F1F5F9',
        900: '#0F172A',
    },
}
```
## 💻 Usage Examples

### Tailwind Config
```javascript
colors: {
  primary: {
    600: '#1E3A8A',
    500: '#2563EB',
    // ...
  },
  accent: {
    500: '#14B8A6',
    // ...
  },
}
```

### CSS Variables
```css
:root {
  --primary-600: #1E3A8A;
  --primary-500: #2563EB;
  --accent-500: #14B8A6;
  --success-500: #10B981;
  --warning-500: #F59E0B;
  --error-500: #EF4444;
}
```
