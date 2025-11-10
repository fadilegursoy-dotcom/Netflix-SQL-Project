netflix_project.+
-- netflix_full_workflow.sql
-- Reproducible SQL pipeline for the Netflix titles dataset
-- Uses tables: netflix_titles (raw), netflix_titles_clean, netflix_titles_clean_backup, netflix_titles_clean_dedup

-- 0. Use database
CREATE DATABASE IF NOT EXISTS netflix_project;
USE netflix_project;

-- 1. Raw table (assumes CSV imported into netflix_titles by user)
-- Keep raw data intact to maintain data lineage and allow re-parsing.
CREATE TABLE IF NOT EXISTS netflix_titles (
  show_id VARCHAR(50),
  type VARCHAR(50),
  title VARCHAR(500),
  director TEXT,
  cast TEXT,
  country VARCHAR(255),
  date_added VARCHAR(255),    -- keep as string here to inspect parsing issues
  release_year VARCHAR(10),
  rating VARCHAR(50),
  duration VARCHAR(100),
  listed_in TEXT,
  description TEXT
);

-- 2. Create a typed clean table
-- Reason: correct data types allow robust aggregation and time series analysis.
CREATE TABLE IF NOT EXISTS netflix_titles_clean (
  show_id VARCHAR(50),
  type VARCHAR(50),
  title VARCHAR(500),
  director TEXT,
  cast TEXT,
  country VARCHAR(255),
  date_added DATE,
  release_year INT,
  rating VARCHAR(50),
  duration VARCHAR(100),
  listed_in TEXT,
  description TEXT
);

-- 3. Insert into clean table with parsing
-- STR_TO_DATE used to convert 'Month dd, yyyy' formats; bad parses will become NULL for manual review.
INSERT INTO netflix_titles_clean (
  show_id, type, title, director, cast, country, date_added, release_year, rating, duration, listed_in, description
)
SELECT
  show_id,
  type,
  title,
  director,
  cast,
  country,
  STR_TO_DATE(NULLIF(date_added, ''), '%M %d, %Y') AS date_added_parsed,
  NULLIF(CAST(NULLIF(release_year, '') AS SIGNED), 0) AS release_year_int,
  rating,
  duration,
  listed_in,
  description
FROM netflix_titles;

-- 4. Sanity checks (manual step)
-- Run these to ensure parsing worked and to inspect NULLs before replacements.
SELECT COUNT(*) AS total_raw FROM netflix_titles;
SELECT COUNT(*) AS total_clean FROM netflix_titles_clean;
SELECT
  SUM(date_added IS NULL) AS null_date_added,
  SUM(release_year IS NULL) AS null_release_year
FROM netflix_titles_clean;

-- 5. Fill blank / NULL textual fields with sentinel 'Unknown'
-- Reason: easier grouping and avoids NULL propagation in aggregations.
UPDATE netflix_titles_clean
SET director = 'Unknown'
WHERE director IS NULL OR TRIM(director) = '';

UPDATE netflix_titles_clean
SET country = 'Unknown'
WHERE country IS NULL OR TRIM(country) = '';

-- 6. Create a backup before destructive ops (dedup)
CREATE TABLE IF NOT EXISTS netflix_titles_clean_backup AS
SELECT * FROM netflix_titles_clean;

-- 7. Deduplicate: create dedup table (distinct rows)
-- Reason: duplicates (same title/year/country) distort counts and trends.
CREATE TABLE IF NOT EXISTS netflix_titles_clean_dedup AS
SELECT DISTINCT
  show_id, type, title, director, cast, country, date_added, release_year, rating, duration, listed_in, description
FROM netflix_titles_clean;

-- Verify counts
SELECT COUNT(*) AS total_after_dedup FROM netflix_titles_clean_dedup;

-- 8. Example analyses (use the dedup table)
-- Top 10 countries by titles
SELECT country, COUNT(*) AS count
FROM netflix_titles_clean_dedup
GROUP BY country
ORDER BY count DESC
LIMIT 10;

-- Movies vs TV Shows
SELECT type, COUNT(*) AS count
FROM netflix_titles_clean_dedup
GROUP BY type;

-- Yearly trend
SELECT release_year, COUNT(*) AS total_titles
FROM netflix_titles_clean_dedup
GROUP BY release_year
ORDER BY release_year ASC;

-- Duration distribution (raw)
SELECT type, duration, COUNT(*) AS cnt
FROM netflix_titles_clean_dedup
GROUP BY type, duration
ORDER BY cnt DESC
LIMIT 30;

-- Rating distribution
SELECT rating, COUNT(*) AS cnt
FROM netflix_titles_clean_dedup
GROUP BY rating
ORDER BY cnt DESC;

-- Most frequent actors (explode trick)
-- Note: this approach assumes cast lists are comma-separated and bounded; for large sets use ETL.
SELECT actor, COUNT(*) AS cnt
FROM (
  SELECT TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(cast, ',', n.n), ',', -1)) AS actor
  FROM netflix_titles_clean_dedup
  JOIN (
    SELECT a.N + b.N * 10 + 1 AS n
    FROM 
      (SELECT 0 AS N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) a,
      (SELECT 0 AS N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) b
  ) n
  ON n.n <= 1 + (LENGTH(cast) - LENGTH(REPLACE(cast, ',', '')))
) all_actors
WHERE actor IS NOT NULL AND actor != ''
GROUP BY actor
ORDER BY cnt DESC
LIMIT 20;

-- Final summary
SELECT
  (SELECT COUNT(*) FROM netflix_titles_clean_dedup) AS total_titles,
  (SELECT COUNT(*) FROM netflix_titles_clean_dedup WHERE type='Movie') AS total_movies,
  (SELECT COUNT(*) FROM netflix_titles_clean_dedup WHERE type='TV Show') AS total_shows,
  (SELECT COUNT(DISTINCT country) FROM netflix_titles_clean_dedup) AS unique_countries,
  (SELECT COUNT(DISTINCT director) FROM netflix_titles_clean_dedup) AS unique_directors;

