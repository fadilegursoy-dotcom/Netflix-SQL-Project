# Netflix SQL Project — Reproducible Workflow

This repository documents a full, reproducible SQL workflow for exploring a Netflix titles dataset using MySQL.  
Everything in this README reflects the actual steps executed during the project (no invented file names). All table names and SQL objects match the work I did.

---

## Project summary

**Goal:** Clean the dataset, remove duplicates, and run basic exploratory analysis using SQL only.

**Database objects used in this project**
- `netflix_titles` — raw imported table (the CSV imported into MySQL)
- `netflix_titles_clean` — typed and cleaned table (date and numeric conversions)
- `netflix_titles_clean_backup` — backup of `netflix_titles_clean` before any destructive ops
- `netflix_titles_clean_dedup` — final deduplicated working table used for analysis

**Main script:** `sql/netflix_full_workflow.sql` (contains the full pipeline and analysis queries)

---

## Rationale & step-by-step workflow

> These are the exact stages we executed and the reason for each.

### 1. Import raw CSV → `netflix_titles`
**Why:** Keep the original dataset untouched so you always have the raw source for reproducibility and to re-run conversions if needed.  
**What we did:** Imported the CSV into a schema table called `netflix_titles` (strings preserved).

---

### 2. Create typed `netflix_titles_clean`
**Why:** Raw CSV stores everything as strings; for reliable analysis we need correct types (DATE, INT). Creating a separate typed table isolates transformations from raw data and prevents accidental corruption.  
**What we did:** Created `netflix_titles_clean` with `date_added DATE`, `release_year INT`, and appropriate varchar/text columns. Then we inserted from `netflix_titles` using `STR_TO_DATE()` for `date_added` and `CAST()` for `release_year`. We allowed parsing failures to produce `NULL` so they can be examined.

---

### 3. Sanity checks & pattern filtering
**Why:** Some records may have malformed `date_added` or `release_year` or empty critical fields. Early detection prevents silent errors downstream.  
**What we did:** Ran `SELECT DISTINCT` and checked `MIN/MAX` and `COUNT(NULL)` for `date_added` and `release_year`. Optionally filtered rows with unexpected formats.

---

### 4. Fill missing values (`director`, `country`) with `'Unknown'`
**Why:** Grouping and counting will be easier and safer if missing textual fields are replaced with a sentinel value. This avoids `NULL` confusion in aggregations and joins.  
**What we did:** `UPDATE netflix_titles_clean SET director = 'Unknown' WHERE director IS NULL OR TRIM(director) = ''` (same for `country`).

---

### 5. Backup before deduplication
**Why:** Deduplication is destructive (removes rows). Always keep a copy to be able to audit or revert.  
**What we did:** Created `netflix_titles_clean_backup` as a full copy of `netflix_titles_clean`.

---

### 6. Deduplicate → `netflix_titles_clean_dedup`
**Why:** Duplicate records (same title, release_year, country) distort counts and trends. Dedup keeps one canonical row per content item.  
**What we did:** Created `netflix_titles_clean_dedup` by selecting DISTINCT rows or via a dedup strategy appropriate to your MySQL version. The working table used for all subsequent analyses was `netflix_titles_clean_dedup`.

---

### 7. Exploratory analyses (examples)
**Why:** To understand distribution of content by country, year, type, duration, rating, directors, and actors. Findings also validate data quality and guide further cleaning.  
**Queries performed (examples):**
- Total records, type breakdown (`Movie` vs `TV Show`)
- Top countries by content count (top 10)
- Top genres (from `listed_in`)
- Top directors and actors
- Time-series: `release_year` trends and `type` by year
- Duration and seasons distribution (raw durations like `90 min`, `1 Season`)
- Rating distribution and country × rating breakdown

---

### 8. Optional enhancements
- Parse `duration` into `duration_minutes` and `seasons_count` for quantitative analysis. (Requires MySQL 8+ or string parsing).
- Create indexes on `country`, `type`, `release_year` for performance.
- Export deduped table to CSV for visualization (Power BI / Python).

---

## Files to include in the GitHub repo
- `sql/netflix_full_workflow.sql` — full script with commented steps (this file)
- `README.md` — this document
- `.gitignore` — ignore raw CSV if you don't want to publish it (recommended)
- `LICENSE` — MIT recommended
- `data/netflix_titles.csv` — optional (DO NOT add if private)

---

## How to run (recommended)
1. Clone the repo locally.
2. Import your original CSV into MySQL as `netflix_titles` (Workbench import or `LOAD DATA INFILE`).
3. Open `sql/netflix_full_workflow.sql` in MySQL Workbench and run step-by-step (do not run all at once; verify counts after each major step).
4. Inspect `netflix_titles_clean_backup` before renaming or overwriting anything.
5. Export `netflix_titles_clean_dedup` if you want an external CSV for BI.

---

## Reproducibility notes
- Everything in the workflow is idempotent except the final `CREATE TABLE ...` steps; keep backups.  
- MySQL 8.0+ recommended for full functionality (e.g., `REGEXP_REPLACE`, window functions).  
- The repository intentionally separates raw → cleaned → dedup tables to make lineage clear.

---

## Short project takeaway (what we found)
- Total records after dedup: **8807**  
- Movies: **6131**, TV Shows: **2676**  
- Top producing countries: **United States, India, (empty country entries handled as 'Unknown')**, United Kingdom, Japan, South Korea, ...  
- Most content concentrated in the 2015–2019 period, peaking in 2018.  
- Most frequent duration category for movies ≈ **90–100 minutes**; most TV shows are **1 Season**.  
- Rating distribution skewed toward **TV-MA** and **TV-14** (adult/young-audience content dominant).

---

## License
MIT — include a `LICENSE` file.

