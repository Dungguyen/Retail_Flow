# Olist Data Quality Report

## 1. Scope
- Project: RetailFlow — Enterprise Data Platform
- Source: Olist Brazilian E-Commerce Dataset
- Database: retail_source
- Schema: raw_olist
- Total orders: 99,441

## 2. Referential Integrity
| Check | Violations | Result |
|---|---:|---|
| Orders → Customers | 0 | PASS |
| Order Items → Orders | 0 | PASS |
| Order Items → Products | 0 | PASS |
| Order Items → Sellers | 0 | PASS |

## 3. Key Quality
- Orders: No duplicate order IDs.
- Customers, Products, Sellers: No duplicate or NULL business keys.
- Order Items: 112,650 rows; no duplicate composite keys.

## 4. Timestamp Quality
| Check | Violations | Result |
|---|---:|---|
| Missing purchase timestamp | 0 | PASS |
| Invalid purchase timestamp format | 0 | PASS |
| Approval before purchase | 0 | PASS |
| Carrier handoff before approval | 1,359 | WARNING |
| Customer delivery before carrier handoff | 23 | WARNING |

## 5. Investigation

### Carrier handoff before approval
- <= 1 hour: 242
- > 1 hour to 1 day: 659
- > 1 day to 7 days: 444
- > 7 days: 14
- Maximum observed difference: 171 days, 5 hours, 15 minutes, 22 seconds.

### Customer delivery before carrier handoff
- Total affected: 23
- Maximum observed difference: 16 days, 2 hours, 18 minutes, 29 seconds.
- All 23 records have status `delivered`.

## 6. Root Cause Status
Root cause remains unconfirmed. Possible explanations include asynchronous updates, timestamp inaccuracies or differences in business event definitions. Further source-system or business-owner verification is required.

## 7. Engineering Decision
- Preserve original source data.
- Flag invalid event sequences in Staging.
- Exclude flagged durations from affected lead-time KPIs until validated.
- Track anomalies in Data Quality monitoring.
- Do not overwrite original timestamps.

## 8. Open Checks
- DQ-008 final numeric validity result: pending confirmation.
- Calendar validity beyond timestamp regex: not fully verified.
- Other Olist tables: comprehensive quality checks not yet completed.