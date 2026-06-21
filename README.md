# Chicago Crime Analysis (2001 - Present)

## Overview
An end-to-end data analysis project exploring 8 million+ 
Chicago crime records from 2001 to present. The goal was 
to identify crime trends, patterns, and insights using 
a full ETL pipeline.

## Tools Used
- **MySQL** — data cleaning and transformation
- **Python** (pandas, matplotlib, seaborn) — exploratory 
  data analysis and visualization
- **Tableau Public** — interactive dashboard

## ETL Process

### Extract
- Downloaded raw dataset from Chicago Data Portal
- Loaded 8M+ rows into MySQL

### Transform (SQL)
- Removed duplicate records
- Standardized `primary_type`, `description`, and 
  `location_description` columns
- Mapped hundreds of abbreviations to full values
- Fixed invalid coordinates (set to NULL)
- Created derived date columns (year, month, hour, 
  day of week)

### Load
- Exported aggregated summary tables to CSV
- Loaded into Python for analysis

## Key Findings
- Chicago crime has declined significantly since 2001
- Theft is the most common crime (~1.8M cases)
- Crime dropped sharply in April 2020 due to 
  COVID-19 lockdowns
- Vice crimes (narcotics, prostitution, gambling) 
  have the highest arrest rates (~99%)
- Crime peaks at midnight on weekends and hits its 
  lowest point between 4-6am

## How to Run
1. Clone this repository
2. Run `CrimeDataScriptDone.sql` in MySQL Workbench
3. Export clean data to CSV
4. Open `CrimeData.ipynb` in Jupyter Notebook
5. Run all cells
