# Exploration Strategies by Application Type

Detailed grep patterns, file locations, and heuristics for discovering features.
Used during Step 2 of the Feature Catalog workflow.

## Table of Contents

1. [Next.js (App Router)](#nextjs-app-router)
2. [Next.js (Pages Router)](#nextjs-pages-router)
3. [React SPA (Vite/CRA)](#react-spa)
4. [Vue / Nuxt](#vue--nuxt)
5. [CLI Tools (Node.js)](#cli-tools-nodejs)
6. [API Services (Express/Fastify/Hono)](#api-services)
7. [Django](#django)
8. [Rails](#rails)
9. [React Native](#react-native)
10. [General Strategies](#general-strategies)

---

## Next.js (App Router)

### Layer 1: Routes
- Glob `app/**/page.tsx` for all pages
- Glob `app/**/layout.tsx` for layout boundaries and navigation
- Check for route groups `(groupName)`, parallel routes `@slot`, intercepting routes `(.)` `(..)`
- Read `<Link>` imports and `useRouter`/`usePathname` usage for navigation structure
- Read `metadata` or `generateMetadata` exports for page titles
- Exclude `app/api/` (these are Layer 3)

### Layer 2: Components
- Trace imports from each `page.tsx` to find interactive components
- Search for `"use client"` directives — these mark interactive features
- Find server actions: `"use server"` in files or inline in components
- Search for form elements: `<form`, `action=`, `onSubmit`

### Layer 3: Supporting
- Glob `app/api/**/route.ts` for API routes
- Read `middleware.ts` for auth/redirect logic
- Search for Supabase/Prisma/Drizzle calls to find data operations
- Check for next-auth, clerk, or lucia for auth features
- Find cron routes or scheduled functions

### Layer 4: Completeness
- Check `next.config.ts` for redirects/rewrites indicating features
- Search for `generateStaticParams` for dynamic content entities
- Find `loading.tsx` and `error.tsx` for feature boundaries

---

## Next.js (Pages Router)

### Layer 1: Routes
- Glob `pages/**/*.tsx` (excluding `_app`, `_document`, `_error`)
- Check `pages/api/` for API routes
- Read `getStaticPaths` for dynamic routes

### Layer 2–4
- Same patterns as App Router, adapted for pages directory

---

## React SPA

### Layer 1: Routes
- Search for `react-router` route definitions: `<Route`, `createBrowserRouter`
- Find lazy-loaded routes: `React.lazy`, `import()`
- Read router config files

### Layer 2: Components
- Search for state management stores (Redux slices, Zustand stores, Jotai atoms)
  — each store often corresponds to a feature domain
- Find context providers wrapping feature boundaries

### Layer 3: Supporting
- Search for API client calls: `fetch(`, `axios.`, `useSWR`, `useQuery`
- Find auth providers and protected route wrappers

---

## Vue / Nuxt

### Layer 1: Routes
- **Nuxt**: Glob `pages/**/*.vue` for file-based routing
- **Vue**: Search for `vue-router` route definitions
- Read `<NuxtLink>` or `<RouterLink>` for navigation

### Layer 2: Components
- Search for `defineEmits`, `@click`, `v-on:` for interactions
- Find composables (`use*.ts`) — each often wraps a feature

### Layer 3: Supporting
- Check `server/api/` (Nuxt) for server routes
- Search for Pinia stores — each store maps to a feature domain

---

## CLI Tools (Node.js)

### Layer 1: Commands
- Search for `commander` program definitions: `.command(`, `.option(`
- Search for `yargs` command definitions: `.command(`, `.option(`
- Read `bin/` entry points
- Find help text strings for feature descriptions

### Layer 2: Features
- Each command's handler function reveals what the command does
- Search for `inquirer` or `prompts` for interactive features
- Find output formatters (table, JSON, CSV output modes)

### Layer 3: Supporting
- Search for config file loading (`.rc` files, `cosmiconfig`)
- Find plugin/extension systems

---

## API Services

### Layer 1: Endpoints
- **Express**: Search for `router.get(`, `router.post(`, `app.get(`
- **Fastify**: Search for `fastify.get(`, `fastify.post(`
- **Hono**: Search for `app.get(`, `app.post(`
- Read OpenAPI/Swagger specs (`openapi.yaml`, `swagger.json`)
- Find route registration files

### Layer 2: Features
- Read request validation schemas for input capabilities
- Find response transformations for output features
- Search for file upload handling (`multer`, `formidable`, `busboy`)

### Layer 3: Supporting
- Find middleware chains (auth, rate limiting, CORS)
- Search for WebSocket/SSE handlers for real-time features
- Check for background job processing (Bull, Agenda, BullMQ)

---

## Django

### Layer 1: Routes
- Read `urls.py` files for URL patterns
- Find `admin.py` for admin panel features
- Read `views.py` or `viewsets.py` for view definitions

### Layer 2: Features
- Read `forms.py` for user input capabilities
- Find `serializers.py` for API data shapes
- Search for template files for rendered UI features

### Layer 3: Supporting
- Find `signals.py` for event-driven features
- Search for management commands in `management/commands/`
- Check for Celery tasks (`@shared_task`, `@app.task`)
- Read `models.py` for data entities

---

## Rails

### Layer 1: Routes
- Read `config/routes.rb` for all routes
- Find controllers in `app/controllers/`
- Check for `resources` and `namespace` declarations

### Layer 2: Features
- Read view templates in `app/views/`
- Find helpers in `app/helpers/`
- Search for `form_for`, `form_with` for input features

### Layer 3: Supporting
- Find mailers in `app/mailers/`
- Search for Active Jobs in `app/jobs/`
- Check concerns in `app/models/concerns/`
- Read migrations for schema insight

---

## React Native

### Layer 1: Screens
- Find navigation definitions: `createStackNavigator`, `createBottomTabNavigator`
- Glob screen components (often in `screens/` or `views/`)
- Read tab/drawer navigator configs for primary feature areas

### Layer 2: Features
- Search for `TouchableOpacity`, `Pressable`, `Button` for actions
- Find `FlatList`, `SectionList` for data display features
- Search for native module bridges (`NativeModules`) for device features

### Layer 3: Supporting
- Search for push notification setup
- Find deep linking configuration
- Check for biometric/auth features

---

## General Strategies

### Grep Patterns for Hidden Features

| What to find | Pattern |
|-------------|---------|
| User-facing messages | `toast\(`, `notify\(`, `alert\(`, `showMessage` |
| Confirmation dialogs | `confirm\(`, `Dialog`, `Modal.*confirm`, `Are you sure` |
| Export capabilities | `export`, `download`, `csv`, `pdf`, `xlsx` |
| Import capabilities | `upload`, `FileReader`, `multer`, `formidable` |
| Search functionality | `useSearch`, `searchParam`, `filter`, `query` |
| Feature flags | `featureFlag`, `isEnabled`, `FF_`, `FEATURE_`, `launchDarkly` |
| Scheduled operations | `cron`, `schedule`, `setInterval`, `@Cron` |
| Email/notifications | `sendEmail`, `nodemailer`, `resend`, `postmark`, `pushNotification` |
| Payment features | `stripe`, `payment`, `checkout`, `subscription`, `billing` |
| Analytics events | `track\(`, `analytics.`, `posthog`, `mixpanel`, `gtag` |

### Reading Test Files for Feature Names

Test descriptions are often the clearest feature documentation:

| Pattern | Example match |
|---------|--------------|
| `describe\("` or `it\("` | `describe("user can filter posts by date")` |
| `test\("` | `test("exports dashboard data as CSV")` |
| `context "` (Ruby) | `context "when user has admin role"` |

### Schema/Model Analysis

Database tables and type definitions reveal the data domain:
- Each table/model usually corresponds to a user-visible entity
- Join tables reveal relationships that may surface as features
- Enum columns reveal finite states/modes the user interacts with
- Timestamp columns like `deleted_at` reveal soft-delete capability
- Columns like `published_at`, `scheduled_for` reveal lifecycle features
