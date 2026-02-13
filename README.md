# Opportunity Intelligence System

An **Opportunity Intelligence System** that provides predictive scoring for Salesforce Opportunities, helping sales teams prioritize deals and improve win rates.

## Overview

This Salesforce DX project delivers AI-powered opportunity insights through a modern, declarative and programmatic architecture. It combines Lightning Web Components (LWC), Apex, REST APIs, and Record-Triggered Flows to surface actionable intelligence directly on Opportunity records and in dashboards.

## Key Capabilities

- **Predictive scoring** – Score opportunities based on factors such as stage, age, amount, engagement, and historical patterns
- **Lightning Web Components (LWC)** – Rich, responsive UI for viewing scores, trends, and recommendations
- **Apex** – Server-side logic for scoring algorithms, integrations, and complex business rules
- **REST APIs** – Integration with external systems and data sources to enrich opportunity intelligence
- **Record-Triggered Flows** – Automate scoring updates, field updates, and notifications when opportunities are created or modified

## Tech Stack

| Component | Technology |
|-----------|------------|
| UI | Lightning Web Components (LWC) |
| Backend | Apex classes & triggers |
| Integration | REST APIs (inbound & outbound) |
| Automation | Record-Triggered Flows |
| Metadata | Salesforce DX source format |

## Project Structure

```
force-app/main/default/
├── aura/           # Aura components (if needed)
├── classes/        # Apex classes
├── flows/          # Record-triggered and screen flows
├── lwc/            # Lightning Web Components
├── objects/        # Custom objects and fields
├── staticresources/
└── triggers/       # Apex triggers
```

## Getting Started

1. **Clone the repository** and open in VS Code with the Salesforce Extensions
2. **Authorize an org**: `sf org login web --alias myorg`
3. **Deploy**: `sf project deploy start`
4. **Create a scratch org** (optional): `sf org create scratch -f config/project-scratch-def.json -a opportunity-intel`

## Development

- Deploy changes: `sf project deploy start`
- Retrieve from org: `sf project retrieve start`
- Run tests: `sf apex run test`

## License

Proprietary. All rights reserved.
