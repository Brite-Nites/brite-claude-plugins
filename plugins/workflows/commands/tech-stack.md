---
description: Display Brite technology stack for tech decisions
---

<!-- eval-waiver: The body is a static reference document (fixed tables of approved languages, frameworks, databases, tooling, plus decision-guideline and what-to-avoid lists); it parses nothing, reads nothing, and decides nothing, so there is no deterministic decide() to test. -->

# Brite Technology Stack

When making technology decisions, use the following established stack. Prefer these technologies over alternatives unless there's a compelling reason to deviate.

## Languages

| Language | Version | Use Case |
|----------|---------|----------|
| **TypeScript** | 5.x | Frontend, Node.js tooling, type-safe applications |
| **Python** | 3.11+ | Backend APIs, data engineering, automation scripts |
| **Liquid** | - | Shopify theme development |

## Frontend

| Technology | Version | Purpose |
|------------|---------|---------|
| **React** | 19.x | UI framework |
| **Next.js** | 15-16.x | Full-stack React framework (preferred for new projects) |
| **Vite** | 7.x | Build tool for non-Next.js projects, Storybook |
| **Tailwind CSS** | 4.x | Styling (utility-first) |
| **Radix UI** | Latest | Headless accessible components |
| **shadcn/ui** | Latest | Component library built on Radix |
| **TanStack Query** | 5.x | Server state management |
| **TanStack Table** | 8.x | Table/data grid components |
| **Recharts** | 2-3.x | Data visualization/charts |
| **Storybook** | 10.x | Component documentation and development |
| **Lucide React** | Latest | Icon library |

## Backend

| Technology | Version | Purpose |
|------------|---------|---------|
| **FastAPI** | 0.104+ | Python async REST APIs |
| **Payload CMS** | 3.x | Headless CMS (with Next.js integration) |
| **SQLAlchemy** | 2.0+ | Python ORM |
| **Alembic** | 1.12+ | Database migrations |
| **Pydantic** | 2.x | Data validation and settings |
| **Zod** | 3-4.x | TypeScript schema validation |

## Databases

| Technology | Use Case |
|------------|----------|
| **PostgreSQL** | Primary relational database |
| **BigQuery** | Data warehouse, analytics |

## Data Engineering

| Technology | Purpose |
|------------|---------|
| **Prefect** | Workflow orchestration |
| **BigQuery** | Data warehouse |
| **dbt** | Data transformations |
| **Google Cloud** | Cloud platform for data infrastructure |

## Testing

| Technology | Language | Purpose |
|------------|----------|---------|
| **Vitest** | TypeScript/JS | Unit and integration tests |
| **Playwright** | TypeScript/JS | End-to-end testing |
| **pytest** | Python | Unit and integration tests |
| **Jest** | TypeScript/JS | Legacy projects (prefer Vitest for new) |
| **Testing Library** | Both | Component testing utilities |

## Package Management

| Tool | Language | Notes |
|------|----------|-------|
| **pnpm** | Node.js | Preferred over npm/yarn |
| **Poetry** | Python | Dependency management |

## Code Quality

| Tool | Language | Purpose |
|------|----------|---------|
| **ESLint** | TypeScript/JS | Linting |
| **Prettier** | TypeScript/JS | Formatting |
| **Black** | Python | Formatting |
| **Ruff** | Python | Fast linting |
| **mypy** | Python | Type checking |
| **pre-commit** | Both | Git hooks |

## Third-Party Integrations

| Service | Purpose |
|---------|---------|
| **HubSpot** | CRM, marketing automation |
| **Slack** | Team communication, notifications |
| **Shopify** | E-commerce platform |
| **Serper.dev** | Search API |

## Infrastructure

| Technology | Purpose |
|------------|---------|
| **Google Cloud Platform** | Primary cloud provider |
| **Docker** | Containerization |
| **GitHub Actions** | CI/CD |

## Decision Guidelines

1. **New frontend project?** → Next.js + Tailwind + shadcn/ui
2. **New API?** → FastAPI (Python) or Next.js API routes (TypeScript)
3. **Need a CMS?** → Payload CMS
4. **Data pipeline?** → Prefect + BigQuery + dbt
5. **Component library work?** → Storybook + Radix UI
6. **Database?** → PostgreSQL for transactional, BigQuery for analytics

## What to Avoid

- **npm/yarn** → Use pnpm instead
- **Redux** → Use TanStack Query for server state, React context for simple client state
- **Styled Components/CSS Modules** → Use Tailwind CSS
- **Express.js** → Use FastAPI or Next.js API routes
- **Moment.js** → Use date-fns
- **AWS** → Use Google Cloud Platform (unless specific requirement)
