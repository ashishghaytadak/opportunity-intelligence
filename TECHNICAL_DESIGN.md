# Opportunity Intelligence System — Technical Design Document

## 1. Executive Summary

The **Opportunity Intelligence System** is a predictive scoring solution for Salesforce Opportunities that helps sales teams prioritize deals, focus on high-probability wins, and improve forecast accuracy. The system calculates a 0–100 score from multiple factors (amount, stage, recency of activity, close date, and engagement), categorizes opportunities as **Hot**, **Warm**, or **Cold**, and surfaces this intelligence through a Lightning Web Component dashboard, Apex REST APIs, and Record-Triggered Flows.

---

## 2. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         OPPORTUNITY INTELLIGENCE SYSTEM                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────────┐     ┌──────────────────┐     ┌──────────────────────┐ │
│  │   LWC Dashboard  │────▶│ Opportunity      │────▶│ OpportunityScoring   │ │
│  │ opportunity      │     │ Scoreboard       │     │ Service (Apex)        │ │
│  │ Scoreboard       │     │ Controller       │     │ - calculateScore()    │ │
│  │                  │     │                  │     │ - categorize()        │ │
│  └──────────────────┘     └──────────────────┘     │ - scoreOpportunities()│ │
│           │                         │               └──────────────────────┘ │
│           │                         │                         │              │
│           ▼                         ▼                         │              │
│  ┌──────────────────┐     ┌──────────────────┐               │              │
│  │  REST API        │────▶│ Opportunity      │───────────────┘              │
│  │ /opportunity-    │     │ (Standard Object)│                               │
│  │ score/*          │     │ + Custom Fields  │                               │
│  │ GET/POST/PATCH   │     └──────────────────┘                               │
│  └──────────────────┘                                                         │
│           │                                                                    │
│           │               ┌──────────────────┐                                 │
│           └──────────────▶│ Record-Triggered │                                 │
│                           │ Flow             │                                 │
│                           │ (Invocable)      │                                 │
│                           └──────────────────┘                                 │
│                                    │                                           │
│                                    ▼                                           │
│                           ┌──────────────────┐                                 │
│                           │ ScoreOpportunity │                                 │
│                           │ Invocable        │                                 │
│                           └──────────────────┘                                 │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Component interactions:**
- **LWC → Apex**: `OpportunityScoreboardController.getOpportunities()` returns scored, open opportunities.
- **REST → Apex**: `OpportunityScoringREST` exposes GET (by ID), POST (score all open), PATCH (score by IDs).
- **Flow → Apex**: `ScoreOpportunityInvocable` is called by Record-Triggered Flows on Opportunity create/update.
- **Core logic**: `OpportunityScoringService` performs all scoring and categorization.

---

## 3. Data Model

| Field Name                | Type           | Purpose                                                                 |
|---------------------------|----------------|-------------------------------------------------------------------------|
| `Opportunity_Score__c`    | Number(5,1)    | Predictive score from 0–100                                             |
| `Score_Category__c`       | Picklist       | Hot, Warm, or Cold                                                      |
| `Last_Scored_Date__c`     | DateTime       | When the opportunity was last scored                                    |
| `Days_Since_Last_Activity__c` | Formula (Number) | Days since `LastActivityDate`; returns 999 if null                    |

---

## 4. Scoring Algorithm

The score is the sum of points from five factors, then clamped to 0–100.

### Factor 1: Amount
| Condition   | Points |
|------------|--------|
| > $100,000 | +30    |
| > $50,000  | +20    |
| > $10,000  | +10    |
| Else       | +5     |

### Factor 2: Stage
| Stage                  | Points |
|------------------------|--------|
| Prospecting            | 5      |
| Qualification          | 10     |
| Needs Analysis         | 20     |
| Value Proposition      | 30     |
| Id. Decision Makers    | 40     |
| Perception Analysis    | 50     |
| Proposal/Price Quote   | 65     |
| Negotiation/Review     | 80     |
| Closed Won             | 100    |
| Closed Lost            | 0      |

### Factor 3: Days Since Last Activity
| Condition | Points |
|-----------|--------|
| < 7 days  | +20    |
| < 30 days | +10    |
| < 60 days | 0      |
| 60+ days  | -10    |
| Null      | 999 (treated as 60+) |

### Factor 4: Close Date
| Condition       | Points |
|-----------------|--------|
| Future          | +10    |
| Past            | -5     |

### Factor 5: Contact Roles
| Condition        | Points |
|------------------|--------|
| Has contact roles| +10    |
| None             | 0      |

### Categorization
| Score   | Category |
|---------|----------|
| ≥ 70    | Hot      |
| 40–69   | Warm     |
| < 40    | Cold     |

---

## 5. API Specification

**Base URL:** `/services/apexrest/opportunity-score`

### GET /opportunity-score/{opportunityId}

Returns score details for a single opportunity.

**Response (200):**
```json
{
  "opportunityId": "006xx0000000000AAA",
  "name": "Acme Corp Deal",
  "score": 75.0,
  "category": "Hot",
  "stageName": "Negotiation/Review",
  "amount": 150000,
  "closeDate": "2025-03-15",
  "daysSinceLastActivity": 3
}
```

### POST /opportunity-score/

Scores all open opportunities (`IsClosed = false`).

**Response (200):**
```json
{
  "scored": 42,
  "status": "success",
  "timestamp": "2025-02-12T14:30:00.000Z"
}
```

### PATCH /opportunity-score/

Scores only the opportunities whose IDs are provided.

**Request body:**
```json
{
  "opportunityIds": ["006xx0000000000AAA", "006xx0000000000BBB"]
}
```

**Response (200):**
```json
[
  {
    "opportunityId": "006xx0000000000AAA",
    "name": "Deal A",
    "score": 82,
    "category": "Hot",
    "stageName": "Negotiation/Review"
  },
  {
    "opportunityId": "006xx0000000000BBB",
    "name": "Deal B",
    "score": 45,
    "category": "Warm",
    "stageName": "Value Proposition"
  }
]
```

---

## 6. Automation

**Record-Triggered Flow:**

- **Object:** Opportunity
- **Trigger:** Create or Update
- **Action:** Call **Score Opportunity** (Invocable)
- **Input:** Record ID(s) of the opportunity(ies) that changed

On create/update, the flow invokes `ScoreOpportunityInvocable`, which calls `OpportunityScoringService.scoreOpportunities()` to recalculate and update `Opportunity_Score__c`, `Score_Category__c`, and `Last_Scored_Date__c`.

---

## 7. LWC Component

**Component:** `opportunityScoreboard`

**Features:**
- **Summary bar:** Total open opportunities, average score, Hot/Warm/Cold counts
- **Filter:** Combobox to filter by Score Category
- **Table:** Name (link), Stage, Amount, Score (progress bar), Category (badge), Close Date
- **Sorting:** Click column headers to sort
- **Empty state:** Message when no scored opportunities exist
- **Styling:** SLDS-based layout; progress bars and badges colored by score/category

**Targets:** App Page, Home Page, Record Page

---

## 8. CI/CD Pipeline

**GitHub Actions workflow:** `.github/workflows/salesforce-ci.yml`

| Trigger      | Jobs                    |
|-------------|--------------------------|
| Push to main | validate-and-test, deploy |
| PR to main   | validate-and-test        |

**Steps:**
1. Checkout code
2. Install Salesforce CLI (`npm install -g @salesforce/cli`)
3. Authenticate with `SFDX_AUTH_URL` (GitHub secret)
4. **validate-and-test:** `sf project deploy start --dry-run --test-level RunLocalTests`
5. **validate-and-test:** `sf apex run test --code-coverage --result-format human`
6. **deploy (push only):** `sf project deploy start --test-level RunLocalTests`

---

## 9. Testing Strategy

- **Target:** ≥92% code coverage across production classes
- **No `seeAllData=true`**
- **Test classes:**
  - `OpportunityScoringServiceTest`: Unit tests for scoring and categorization
  - `OpportunityScoringRESTTest`: REST endpoints with `RestContext`
  - `ScoreOpportunityInvocableTest`: Invocable behavior
  - `OpportunityScoreboardControllerTest`: Controller query and filters
- **Scenarios:** Edge cases (null amount, past close date), boundary values (0, 39, 40, 69, 70, 100), empty and invalid inputs, bulk operations

---

## 10. Future Enhancements

| Enhancement                | Description                                                                 |
|---------------------------|-----------------------------------------------------------------------------|
| Einstein AI integration   | Use Einstein Prediction Builder or similar models for richer predictions    |
| Historical trend tracking | Store score history and visualize changes over time                         |
| Email alerts              | Notify owners when scores drop below a threshold or category changes        |
| Batch scoring scheduler   | Scheduled Apex to score all open opportunities (e.g. nightly)               |
| Custom weights            | Custom metadata or Custom Settings to configure factor weights per org      |
| Integration with CPQ      | Incorporate quote and product data into scoring                             |
| Mobile optimization       | Responsive layout and actions for Salesforce Mobile                         |
