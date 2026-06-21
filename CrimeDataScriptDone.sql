USE crime;

CREATE TABLE CrimeData_Raw (
    ID INT PRIMARY KEY,
    CaseNumber VARCHAR(20),
    Date DATETIME,               -- We will use STR_TO_DATE during import
    Block VARCHAR(100),
    IUCR VARCHAR(10),
    PrimaryType VARCHAR(100),
    Description VARCHAR(255),
    LocationDescription VARCHAR(255),
    Arrest TEXT,              -- Stores as 0 or 1
    Domestic TEXT,            -- Stores as 0 or 1
    Beat INT,
    District INT,
    Ward INT,                    -- Chicago has 50 wards
    CommunityArea INT,           -- Chicago has 77 community areas
    FBICode VARCHAR(10),
    XCoordinate INT,
    YCoordinate INT,
    Year INT,
    UpdatedOn DATETIME,
    Latitude DECIMAL(15, 10),
    Longitude DECIMAL(15, 10),
    Location VARCHAR(100)
);
SET GLOBAL local_infile = 1;
LOAD DATA LOCAL INFILE 'C:/Users/marca/Downloads/CrimesData.csv'
INTO TABLE crimedata_raw
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(ID, CaseNumber, @DateVar, Block, IUCR, PrimaryType, Description, LocationDescription, 
 Arrest, Domestic, Beat, District, Ward, CommunityArea, FBICode, XCoordinate, 
 YCoordinate, Year, UpdatedOn, Latitude, Longitude, Location)
SET Date = STR_TO_DATE(@DateVar, '%m/%d/%Y %r');

SET GLOBAL net_read_timeout = 3600;
SET GLOBAL net_write_timeout = 3600;
SET GLOBAL wait_timeout = 3600;
SET GLOBAL interactive_timeout = 3600;
SET GLOBAL max_allowed_packet = 268435456;
SET SESSION sql_mode = '';

SELECT
	SUM(CASE WHEN `ID` IS NULL THEN 1 ELSE 0 END)             AS NULL_ID,
	SUM(CASE WHEN `CaseNumber`IS NULL THEN 1 ELSE 0 END)      AS NULL_CaseNumber,
    SUM(CASE WHEN `Date` IS NULL THEN 1 ELSE 0 END)    	      AS NULL_Date,
    SUM(CASE WHEN `PrimaryType` IS NULL THEN 1 ELSE 0 END)    AS NULL_PrimaryType,
    SUM(CASE WHEN `Latitude` IS NULL THEN 1 ELSE 0 END)       AS NULL_Lat,
    SUM(CASE WHEN `Longitude` IS NULL THEN  1 ELSE 0 END)     AS NULL_Long,
    SUM(CASE WHEN `Arrest` IS NULL THEN 1 ELSE 0 END)         AS NULL_Arrest,
    SUM(CASE WHEN `District` IS NULL THEN 1 ELSE 0 END)       AS NULL_District
FROM CrimeData_Raw;

SELECT 
    COUNT(*) AS total_rows,
    COUNT(DISTINCT `CaseNumber`) AS unique_cases,
    COUNT(*) - COUNT(DISTINCT `CaseNumber`) AS duplicates_remaining
FROM CrimeData_Raw;

Create Table CrimeData_Clean Like CrimeData_Raw;

SELECT YEAR(`Date`) AS year, COUNT(*) AS total_rows
FROM CrimeData_Raw
GROUP BY YEAR(`Date`)
ORDER BY year;

INSERT INTO CrimeData_Clean (
    `ID`, `CaseNumber`, `Date`, `Block`, `IUCR`,
    `PrimaryType`, `Description`, `LocationDescription`,
    `Arrest`, `Domestic`, `Beat`, `District`, `Ward`,
    `CommunityArea`, `FBICode`, `XCoordinate`, `YCoordinate`,
    `Year`, `UpdatedOn`, `Latitude`, `Longitude`, `Location`
)
WITH CTE_Deduplicate AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY `CaseNumber`
            ORDER BY `ID` DESC
        ) AS row_num
    FROM CrimeData_Raw
    Where year = 2016                                         --  year 2001 - 2026
)
SELECT 
    `ID`, `CaseNumber`, `Date`, `Block`, `IUCR`,
    `PrimaryType`, `Description`, `LocationDescription`,
    `Arrest`, `Domestic`, `Beat`, `District`, `Ward`,
    `CommunityArea`, `FBICode`, `XCoordinate`, `YCoordinate`,
    `Year`, `UpdatedOn`, `Latitude`, `Longitude`, `Location`
FROM CTE_Deduplicate
WHERE row_num = 1;

SELECT 'Raw' AS table_name, COUNT(*) AS total_rows FROM CrimeData_Raw
UNION ALL
SELECT 'Clean', COUNT(*) FROM CrimeData_Clean;

SELECT 
    COUNT(*) AS total_rows,
    COUNT(DISTINCT `CaseNumber`) AS unique_cases,
    COUNT(*) - COUNT(DISTINCT `CaseNumber`) AS duplicates_remaining
FROM CrimeData_Clean;

SELECT `CaseNumber`, COUNT(*) AS occurrences
FROM CrimeData_Clean
GROUP BY `CaseNumber`
HAVING COUNT(*) > 1;

Select *  from CrimeData_Clean 
where CaseNumber = 'G262626';

SELECT `ID`, `CaseNumber`, `Date`, `Year`
from CrimeData_Clean 
where `CaseNumber` IN (
	Select `CaseNumber`
    From CrimeData_Clean 
    Group By `CaseNumber`
    Having Count(*) > 1
    )
Order By `CaseNumber`, `Date`;

Delete
from CrimeData_Clean
Where `ID` in (1700,27321,23066,26769,27734,28933,27947);

Select DISTINCT `PrimaryType`
From CrimeData_Clean
Order By `PrimaryType` asc;

Update CrimeData_Clean
Set Primarytype =  'CRIMINAL SEXUAL ASSAULT'
Where PrimaryType = 'CRIM SEXUAL ASSAULT';

UPDATE CrimeData_Clean
SET PrimaryType =
    CASE 
        -- 3 words
        WHEN LENGTH(PrimaryType) - LENGTH(REPLACE(PrimaryType, ' ', '')) >= 2 THEN
            CONCAT(
                UPPER(LEFT(SUBSTRING_INDEX(PrimaryType, ' ', 1), 1)), LOWER(SUBSTRING(SUBSTRING_INDEX(PrimaryType, ' ', 1), 2)), ' ',
                UPPER(LEFT(SUBSTRING_INDEX(SUBSTRING_INDEX(PrimaryType, ' ', 2), ' ', -1), 1)), LOWER(SUBSTRING(SUBSTRING_INDEX(SUBSTRING_INDEX(PrimaryType, ' ', 2), ' ', -1), 2)), ' ',
                UPPER(LEFT(SUBSTRING_INDEX(PrimaryType, ' ', -1), 1)), LOWER(SUBSTRING(SUBSTRING_INDEX(PrimaryType, ' ', -1), 2))
            )
        -- 2 words
        WHEN LOCATE(' ', PrimaryType) > 0 THEN
            CONCAT(
                UPPER(LEFT(SUBSTRING_INDEX(PrimaryType, ' ', 1), 1)), LOWER(SUBSTRING(SUBSTRING_INDEX(PrimaryType, ' ', 1), 2)), ' ',
                UPPER(LEFT(SUBSTRING_INDEX(PrimaryType, ' ', -1), 1)), LOWER(SUBSTRING(SUBSTRING_INDEX(PrimaryType, ' ', -1), 2))
            )
        -- 1 word
        ELSE
            CONCAT(UPPER(LEFT(PrimaryType, 1)), LOWER(SUBSTRING(PrimaryType, 2)))
    END;

SELECT description, COUNT(*) AS cnt
FROM CrimeData_Clean
WHERE description REGEXP '^(MANU|POSS|AGG|ATT|PRO |DEL )'
GROUP BY description
ORDER BY cnt desc
LIMIT 30;


UPDATE CrimeData_Clean SET description = 'POSSESS - COCAINE'
WHERE description = 'POSS: COCAINE';

UPDATE CrimeData_Clean SET description = 'POSSESS - HEROIN (WHITE)'
WHERE description = 'POSS: HEROIN(WHITE)';

Update CrimeData_Clean SET description = 'POSSESS - CRACK'
WHERE description = 'POSS: CRACK';

UPDATE CrimeData_Clean SET description = 'POSSESS - AMPHETAMINES'
where description = 'POSS: AMPHETAMINES';

UPDATE CrimeData_Clean SET description = 'POSSESS - BARBITURATES'
WHERE description = 'POSS: BARBITUATES';

UPDATE CrimeData_Clean SET description = 'POSSESS - CANNABIS 30 GRAMS OR LESS'
WHERE description = 'POSS: CANNABIS 30GMS OR LESS';

UPDATE CrimeData_Clean Set description = 'POSSESS - CANNABIS MORE THAN 30 GRAMS'
where description = 'POSS: CANNABIS MORE THAN 30GMS';

UPDATE CrimeData_Clean SET description = 'POSSESS - HALLUCINOGENS'
Where description = 'POSS: HALLUCINOGENS';

Update CrimeData_Clean Set description = 'POSSESS - HEROIN (BLACK TAR)'
where description = 'POSS: HEROIN(BLACK TAR)';

update CrimeData_Clean SET description = 'POSSESS - HEROIN (TAN / BROWN TAR)'
Where description = 'POSS: HEROIN(BRN/TAN)';

UPDATE CrimeData_Clean SET description = 'POSSESS - PCP'
WHERE description = 'POSS: PCP';

UPDATE CrimeData_Clean SET description = 'POSSESS - METHAMPHETAMINE'
WHERE description = 'POSS: METHAMPHETAMINES';

UPDATE CrimeData_Clean SET description = 'POSSESS - SYNTHETIC DRUGS'
WHERE description = 'POSS: SYNTHETIC DRUGS';

UPDATE CrimeData_Clean SET description = 'POSSESS - LOOK-ALIKE DRUGS'
WHERE description = 'POSS: LOOK-ALIKE DRUGS';

UPDATE CrimeData_Clean SET description = 'POSSESS FIREARM / AMMUNITION - NO FOID CARD'
WHERE description = 'POSS FIREARM/AMMO:NO FOID CARD';

UPDATE CrimeData_Clean SET description = 'POSSESS KEYS OR DEVICE TO COIN MACHINE'
WHERE description = 'POSS. KEYS OR DEV.TO COIN MACH';

UPDATE CrimeData_Clean SET description = 'POSSESSION - SYNTHETIC MARIJUANA'
WHERE description = 'POSSESSION: SYNTHETIC MARIJUANA';

SELECT description, COUNT(*) AS cnt
FROM CrimeData_Clean
WHERE description LIKE 'MANU%'
GROUP BY description
ORDER BY description;

UPDATE CrimeData_Clean SET description = 'MANUFACTURE / DELIVER - CANNABIS 10 GRAMS OR LESS'
WHERE description = 'MANU/DEL:CANNABIS 10GM OR LESS';

UPDATE CrimeData_Clean SET description = 'MANUFACTURE / DELIVER - CANNABIS OVER 10 GRAMS'
WHERE description = 'MANU/DEL:CANNABIS OVER 10 GMS';

UPDATE CrimeData_Clean SET description = 'MANUFACTURE / DELIVER - HALLUCINOGEN'
WHERE description = 'MANU/DELIVER: HALLUCINOGEN';

UPDATE CrimeData_Clean SET description = 'MANUFACTURE / DELIVER -  HEROIN (WHITE)'
WHERE description = 'MANU/DELIVER: HEROIN (WHITE)';

UPDATE CrimeData_Clean SET description = 'MANUFACTURE / DELIVER - HEROIN (TAN / BROWN TAR)'
WHERE description = 'MANU/DELIVER: HEROIN(BRN/TAN)';

UPDATE CrimeData_Clean SET description = 'MANUFACTURE / DELIVER - HEROIN (BLACK TAR)'
WHERE description = 'MANU/DELIVER:HEROIN(BLACK TAR)';

UPDATE CrimeData_CLean SET description = 'MANUFACTURE / DELIVER - METHAMPHETAMINE' 
WHERE description = 'MANU/DELIVER: METHAMPHETAMINES';

UPDATE CrimeData_CLean SET description = 'MANUFACTURE / DELIVER - AMPHETAMINES'
WHERE description = 'MANU/DELIVER:AMPHETAMINES';

UPDATE CrimeData_CLean SET description = 'MANUFACTURE / DELIVER - BARBITURATES'
WHERE description = 'MANU/DELIVER:BARBITUATES';

UPDATE CrimeData_Clean SET description = 'MANUFACTURE / DELIVER - COCAINE'
WHERE description = 'MANU/DELIVER:COCAINE';

UPDATE CrimeData_Clean SET description = 'MANUFACTURE / DELIVER - CRACK'
WHERE description = 'MANU/DELIVER:CRACK';

UPDATE CrimeData_Clean SET description = 'MANUFACTURE / DELIVER - LOOK-ALIKE DRUG'
WHERE description = 'MANU/DELIVER:LOOK-ALIKE DRUG';

UPDATE CrimeData_Clean SET description = 'MANUFACTURE / DELIVER - PCP'
WHERE description = 'MANU/DELIVER:PCP';

UPDATE CrimeData_Clean SET description = 'MANUFACTURE / DELIVER - SYNTHETIC DRUGS'
WHERE description = 'MANU/DELIVER:SYNTHETIC DRUGS';

UPDATE CrimeData_Clean SET description = 'MANUFACTURE / DELIVER - SYNTHETIC MARIJUANA'
WHERE description =  'MANU/POSS. W/INTENT TO DELIVER: SYNTHETIC MARIJUANA';

UPDATE CrimeData_Clean
SET description = 'MANUFACTURE / DELIVER - HEROIN (WHITE)'
WHERE description = 'MANUFACTURE / DELIVER -  HEROIN (WHITE)';
                                     
SELECT description, COUNT(*) AS cnt
FROM CrimeData_Clean
WHERE description LIKE 'AGG%'
GROUP BY description
ORDER BY description ;

Update CrimeData_Clean SET description = 'AGGRAVATED - HANDS, FISTS, FEET, NO / MINOR INJURY'
WHERE description = 'AGG: HANDS/FIST/FEET NO/MINOR INJURY';

UPDATE CrimeData_Clean SET description = 'AGGRAVATED - HANDS, FISTS, FEET, SERIOUS INJURY'
WHERE description = 'AGG: HANDS/FIST/FEET SERIOUS INJURY';

UPDATE CrimeData_Clean SET description = 'AGGRAVATED - HANDGUN'
WHERE description = 'AGGRAVATED: HANDGUN';

UPDATE CrimeData_Clean SET description = 'AGGRAVATED - KNIFE / CUTTING INSTRUMENT'
WHERE description = 'AGGRAVATED: KNIFE / CUTTING INSTRUMENT';

UPDATE CrimeData_Clean SET description = 'AGGRAVATED - KNIFE / CUTTING INSTRUMENT'
WHERE description = 'AGGRAVATED: KNIFE/CUT INSTR';

UPDATE CrimeData_Clean SET description = 'AGGRAVATED - OTHER' 
WHERE description = 'AGGRAVATED: OTHER';

Update CrimeData_Clean SET description = 'AGGRAVATED - OTHER DANGEROUS WEAPON'
WHERE description = 'AGGRAVATED: OTHER DANG WEAPON';

Update CrimeData_Clean SET description = 'AGGRAVATED - OTHER DANGEROUS WEAPON'
WHERE description = 'AGGRAVATED: OTHER DANGEROUS WEAPON';

UPDATE CrimeData_Clean SET description = 'AGGRAVATED - OTHER FIREARM'
WHERE description = 'AGGRAVATED: OTHER FIREARM';

UPDATE CrimeData_Clean SET description = 'AGGRAVATED FINANCIAL IDENTITY THEFT'
Where description = 'AGGRAVATED: FINANCIAL IDENTITY THEFT';

UPDATE CrimeData_Clean SET description = 'AGGRAVATED FINANCIAL IDENTITY THEFT'
WHERE description = 'AGG: FINANCIAL ID THEFT';

UPDATE CrimeData_Clean SET description = 'AGGRAVATED - HANDS, FISTS, FEET, NO / MINOR INJURY'
WHERE description = 'AGGRAVATED: HANDS / FIST / FEET NO / MINOR INJURY';

UPDATE CrimeData_Clean SET description = 'AGGRAVATED - HANDS, FISTS, FEET, SERIOUS INJURY'
WHERE description = 'AGGRAVATED: HANDS / FIST / FEET SERIOUS INJURY';

UPDATE CrimeData_Clean SET description = 'AGGRAVATED - KNIFE / CUTTING INSTRUMENT'
WHERE description = 'AGGRAVATED:KNIFE/CUTTING INSTR';

UPDATE CrimeData_Clean SET description = 'AGGRAVATED DOMESTIC BATTERY - HANDS, FISTS, FEET, SERIOUS INJURY'
WHERE description = 'AGG. DOMESTIC BATTERY - HANDS, FISTS, FEET, SERIOUS INJURY';

UPDATE CrimeData_Clean SET description = 'AGGRAVATED DOMESTIC BATTERY - HANDS, FISTS, FEET, SERIOUS INJURY'
WHERE description = 'AGGRAVATED DOMESTIC BATTERY: HANDS/FIST/FEET SERIOUS INJURY';

UPDATE CrimeData_Clean SET description = 'AGGRAVATED DOMESTIC BATTERY - HANDGUN'
WHERE description = 'AGGRAVATED DOMESTIC BATTERY: HANDGUN';

UPDATE CrimeData_Clean SET description = 'AGGRAVATED DOMESTIC BATTERY - KNIFE / CUTTING INSTRUMENT'
WHERE description = 'AGGRAVATED DOMESTIC BATTERY: KNIFE / CUTTING INSTSTRUMENT';

UPDATE CrimeData_Clean SET description = 'AGGRAVATED DOMESTIC BATTERY - KNIFE / CUTTING INSTRUMENT'
WHERE description = 'AGGRAVATED DOMESTIC BATTERY: KNIFE/CUTTING INST';

UPDATE CrimeData_Clean SET description = 'AGGRAVATED DOMESTIC BATTERY - OTHER DANGEROUS WEAPON' 
WHERE description = 'AGGRAVATED DOMESTIC BATTERY: OTHER DANG WEAPON';

UPDATE CrimeData_Clean SET description =  'AGGRAVATED DOMESTIC BATTERY - OTHER DANGEROUS WEAPON' 
WHERE description = 'AGGRAVATED DOMESTIC BATTERY: OTHER DANGEROUS WEAPON';

UPDATE CrimeData_Clean SET description = 'AGGRAVATED DOMESTIC BATTERY - OTHER FIREARM'
WHERE description = 'AGGRAVATED DOMESTIC BATTERY: OTHER FIREARM';

UPDATE CrimeData_Clean SET description = 'AGGRAVATED POLICE OFFICER - HANDS, FISTS, FEET, NO INJURY'
Where description = 'AGGRAVATED P.O. - HANDS, FISTS, FEET, NO / MINOR INJURY';

UPDATE CrimeData_Clean SET description = 'AGGRAVATED POLICE OFFICER - HANDS, FISTS, FEET, SERIOUS INJURY'
Where description = 'AGG PO HANDS ETC SERIOUS INJ';

UPDATE CrimeData_Clean set description = 'AGGRAVATED POLICE OFFICER - HANDS, FISTS, FEET, NO INJURY'
WHERE description = 'AGG PO HANDS NO/MIN INJURY';

UPDATE Crimedata_Clean SET description = 'AGGRAVATED POLICE OFFICER - HANDS, FISTS, FEET, SERIOUS INJURY'
WHERE description = 'AGGRAVATED P.O. - HANDS, FISTS, FEET, SERIOUS INJURY';

UPDATE CrimeData_Clean SET description = 'AGGRAVATED POLICE OFFICER - HANDGUN'
WHERE description = 'AGGRAVATED PO: HANDGUN';

UPDATE CrimeData_Clean SET description = 'AGGRAVATED POLICE OFFICER - KNIFE / CUTTING INSTRUMENT'
WHERE description = 'AGGRAVATED PO:KNIFE/CUT INSTR';

UPDATE CrimeData_Clean SET description = 'AGGRAVATED POLICE OFFICER - KNIFE / CUTTING INSTRUMENT'
WHERE description = 'AGGRAVATED PO: KNIFE/CUT INSTR';

UPDATE CrimeData_Clean SET description = 'AGGRAVATED POLICE OFFICER - OTHER DANGEROUS WEAPON'
WHERE description = 'AGGRAVATED PO: OTHER DANG WEAP';

UPDATE CrimeData_Clean SET description = 'AGGRAVATED POLICE OFFICER - OTHER DANGEROUS WEAPON'
WHERE description = 'AGGRAVATED PO: OTHER DANGEROUS WEAPON';

UPDATE CrimeData_Clean SET description = 'AGGRAVATED POLICE OFFICER - OTHER FIREARM'
WHERE description = 'AGGRAVATED PO: OTHER FIREARM';

UPDATE CrimeData_Clean SET description = 'AGGRAVATED PROTECTED EMPLOYEE - HANDS, FISTS, FEET, SERIOUS INJURY'
WHERE description = 'AGG PRO EMP HANDS SERIOUS INJ';

UPDATE CrimeData_Clean SET description = 'AGGRAVATED PROTECTED EMPLOYEE - HANDS, FISTS, FEET, SERIOUS INJURY'
WHERE description = 'AGG. PROTECTED EMPLOYEE - HANDS, FISTS, FEET, SERIOUS INJURY';

UPDATE CrimeData_Clean SET description = 'AGGRAVATED PROTECTED EMPLOYEE - HANDGUN'
WHERE Description = 'AGG PRO.EMP: HANDGUN';

UPDATE CrimeData_Clean SET description = 'AGGRAVATED PROTECTED EMPLOYEE - KNIFE / CUTTING INSTRUMENT'
WHERE description = 'AGG PRO.EMP:KNIFE/CUTTING INST';

UPDATE CrimeData_Clean SET description = 'AGGRAVATED PROTECTED EMPLOYEE - OTHER DANGEROUS WEAPON'
WHERE description  = 'AGG PRO.EMP: OTHER DANG WEAPON';

UPDATE CrimeData_Clean SET description = 'AGGRAVATED POLICE OFFICER - OTHER FIREARM'
WHERE description ='AGG PRO.EMP: OTHER FIREARM' ;

UPDATE CrimeData_CLean SET description = 'AGGRAVATED CRIMINAL SEXUAL ABUSE'
WHERE description = 'AGG CRIM SEX ABUSE - VIC 13-16 YOA - OFF 5 YR OLDER PENETRAT';

UPDATE CrimeData_Clean SET description =  'AGGRAVATED CRIMINAL SEXUAL ABUSE'
WHERE description = 'AGG CRIMINAL SEXUAL ABUSE';

UPDATE CrimeData_CLean SET description = 'AGGRAVATED CRIMINAL SEXUAL ABUSE BY FAMILY MEMBER'
WHERE description = 'AGG CRIM SEX ABUSE FAM MEMBER';

UPDATE CrimeData_Clean SET description = 'AGGRAVATED SEXUAL ASSAULT OF CHILD BY FAMILY MEMBER'
WHERE description = 'AGG SEX ASSLT OF CHILD FAM MBR';

UPDATE CrimeData_Clean SET description = 'AGGRAVATED RITUAL MUTILATION - HANDS, FISTS, FEET, NO / MINOR INJURY'
WHERE description = 'AGG RIT MUT: HANDS/FIST/FEET NO/MINOR INJURY';

UPDATE CrimeData_Clean SET description = 'AGGRAVATED RITUAL MUTILATION - HANDS, FISTS, FEET, SERIOUS INJURY'
WHERE description = 'AGG RIT MUT: HANDS/FIST/FEET SERIOUS INJURY';

UPDATE CrimeData_CLean SET description = 'AGGRAVATED RITUAL MUTILATION - HANDS, FISTS, FEET, SERIOUS INJURY'
WHERE description = 'AGG. RITUAL MUTILATION - HANDS, FISTS, FEET, SERIOUS INJURY';

UPDATE CrimeData_Clean SET description = 'AGGRAVATED RITUAL MUTILATION - HANDGUN'
WHERE description = 'AGG RITUAL MUT:HANDGUN';

UPDATE CrimeData_Clean SET description = 'AGGRAVATED RITUAL MUTILATION - KNIFE / CUTTING INSTRUMENT'
WHERE description = 'AGG RITUAL MUT:KNIFE/CUTTING I';

UPDATE CrimeData_Clean SET description = 'AGGRAVATED RITUAL MUTILATION - OTHER DANGEROUS WEAPON'
WHERE description = 'AGG RITUAL MUT:OTH DANG WEAPON';

UPDATE CrimeData_Clean SET description = 'AGGRAVATED OF AN UNBORN CHILD'
WHERE description = 'AGGRAVATED OF A UNBORN CHILD';

UPDATE CrimeData_Clean SET description = 'AGGRAVATED OF AN SENIOR CITIZEN'
WHERE description = 'AGGRAVATED OF A SENIOR CITIZEN';

SELECT description, count(*) AS CNT
From CrimeData_Clean 
Where description LIKE 'ATT%"' OR
description LIKE 'ATTEMPT%'
Group BY description 
ORDER BY description;

UPDATE CrimeData_Clean SET description = 'ATTEMPT AGGRAVATED' 
WHERE description = 'ATTEMPT: AGGRAVATED';

UPDATE CrimeData_Clean SET description = 'ATTEMPT AGGRAVATED - HANDGUN' 
WHERE description = 'ATTEMPT AGG: HANDGUN';

UPDATE CrimeData_Clean SET description = 'ATTEMPT AGGRAVATED - KNIFE / CUTTING INSTRUMENT'
WHERE description = 'ATTEMPT AGG: KNIFE/CUT INSTR';

UPDATE CrimeData_Clean SET description = 'ATTEMPT AGGRAVATED - OTHER DANGEROUS WEAPON'
WHERE description = 'ATTEMPT AGG: OTHER DANG WEAPON';

UPDATE CrimeData_CLean SET description = 'ATTEMPT AGGRAVATED - OTHER FIREARM'
WHERE description = 'ATTEMPT AGG: OTHER FIREARM';

UPDATE CrimeData_Clean SET description = 'ATTEMPT AGGRAVATED - OTHER'
WHERE description = 'ATTEMPT AGG: OTHER';

UPDATE CrimeData_Clean SET description = 'ATTEMPT ARMED - HANDGUN'
WHERE description = 'ATTEMPT ARMED: HANDGUN';

UPDATE CrimeData_Clean SET description = 'ATTEMPT ARMED - HANDGUN'
WHERE description = 'ATTEMPT: ARMED-HANDGUN';

UPDATE CrimeData_Clean SET description = 'ATTEMPT AGGRAVATED - KNIFE / CUTTING INSTRUMENT'
WHERE description = 'ATTEMPT: ARMED-KNIFE/CUT INSTR';

UPDATE CrimeData_CLean SET description = 'ATTEMPT ARMED - OTHER DANGEROUS WEAPON'
WHERE description = 'ATTEMPT: ARMED-OTHER DANG WEAP';

UPDATE CrimeData_Clean SET description = 'ATTEMPT ARMED - OTHER FIREARM'
WHERE description = 'ATTEMPT: ARMED-OTHER FIREARM';

UPDATE CrimeData_Clean SET description = 'ATTEMPT STRONG ARM - NO WEAPON'
WHERE description = 'ATTEMPT STRONG ARM: NO WEAPON';

UPDATE CrimeData_Clean SET description = 'ATTEMPT STRONG ARM - NO WEAPON'
WHERE description = 'ATTEMPT: STRONGARM-NO WEAPON';

UPDATE CrimeData_Clean SET description = 'ATTEMPT - CYCLE, SCOOTER, BIKE NO VIN'
WHERE description = 'ATTEMPT: CYCLE, SCOOTER, BIKE NO VIN';

UPDATE CrimeData_Clean SET description = 'ATTEMPT - CYCLE, SCOOTER, BIKE WITH VIN'
WHERE description = 'ATTEMPT: CYCLE, SCOOTER, BIKE W-VIN';

SELECT description, COUNT(*) AS cnt
FROM CrimeData_Clean
WHERE description REGEXP '^(ARMED|STRONG|THEFT|STOLEN|SEX|SELL|SOLICIT|UNLAWFUL|VIOL)'
GROUP BY description
ORDER BY description;

SELECT description, COUNT(*) AS cnt
FROM CrimeData_Clean 
WHERE description LIKE 'vio%'
GROUP BY description 
ORDER BY description ASC;

UPDATE CrimeData_Clean SET description = 'ARMED - HANDGUN'
WHERE description = 'ARMED: HANDGUN';

UPDATE CrimeData_Clean SET description = 'ARMED - KNIFE / CUTTING INSTRUMENT'
WHERE description = 'ARMED:KNIFE/CUTTING INSTRUMENT';

UPDATE CrimeData_Clean SET description = 'ARMED - OTHER DANGEROUS WEAPON'
WHERE description = 'ARMED: OTHER DANGEROUS WEAPON';

UPDATE CrimeData_clean SET description = 'ARMED - OTHER FIREARM'
WHERE description = 'ARMED: OTHER FIREARM';

UPDATE CrimeData_Clean SET description = 'STRONG ARM - NO WEAPON'
WHERE description = 'STRONGARM - NO WEAPON';

UPDATE CrimeData_Clean SET description = 'STRONG ARM - NO WEAPON'
WHERE description = 'STRONGARM: NO WEAPON';

UPDATE CrimeData_Clean SET description = 'THEFT / RECOVERY - AUTOMOBILE'
WHERE description = 'THEFT/RECOVERY: AUTOMOBILE';

UPDATE CrimeData_Clean SET description = 'THEFT / RECOVERY - CYCLE, SCOOTER, BIKE NO VIN'
WHERE description = 'THEFT/RECOVERY: CYCLE, SCOOTER, BIKE NO VIN';

UPDATE CrimeData_Clean SET description = 'THEFT / RECOVERY - CYCLE, SCOOTER, BIKE WITH VIN'
WHERE description = 'THEFT/RECOVERY: CYCLE, SCOOTER, BIKE W-VIN';

UPDATE CrimeData_Clean SET description = 'THEFT / RECOVERY - TRUCK, BUS, MOBILE HOME'
WHERE description = 'THEFT/RECOVERY: TRUCK,BUS,MHOME';

UPDATE CrimeData_Clean SET description = 'THEFT BY LESSEE, MOTOR VEHICLE'
WHERE description = 'THEFT BY LESSEE,MOTOR VEH';

UPDATE CrimeData_Clean SET description = 'THEFT BY LESSEE, NON-MOTOR VEHICLE'
WHERE description = 'THEFT BY LESSEE,NON-VEH';

UPDATE CrimeData_Clean SET description = 'THEFT OF LABOR / SERVICES'
WHERE description = 'THEFT OF LABOR/SERVICES';

UPDATE CrimeData_Clean SET description = 'THEFT OF LOST / MISLAID PROPERTY'
WHERE description = 'THEFT OF LOST/MISLAID PROP';

UPDATE CrimeData_Clean SET description = 'STOLEN PROPERTY BUY / RECEIVE / POSSESS'
WHERE description = 'STOLEN PROP: BUY/RECEIVE/POS.';

UPDATE CrimeData_Clean SET description = 'SEX OFFENDER - FAIL TO REGISTER'
WHERE description = 'SEX OFFENDER: FAIL TO REGISTER';

UPDATE CrimeData_Clean SET description = 'SEX OFFENDER - FAIL TO REGISTER NEW ADDRESS'
WHERE description = 'SEX OFFENDER: FAIL REG NEW ADD';

UPDATE CrimeData_Clean SET description = 'SEX OFFENDER - PROHIBITED ZONE'
WHERE description = 'SEX OFFENDER: PROHIBITED ZONE';

UPDATE CrimeData_Clean SET description = 'SEXUAL ASSAULT OF CHILD BY FAMILY MEMBER'
WHERE description = 'SEX ASSLT OF CHILD BY FAM MBR';

UPDATE CrimeData_Clean SET description = 'SEXUAL RELATIONS IN FAMILY'
WHERE description = 'SEX RELATION IN FAMILY';

UPDATE CrimeData_Clean SET description = 'SOLICITING FOR BUSINESS'
WHERE description = 'SOLICIT FOR BUSINESS';

UPDATE CrimeData_Clean SET description = 'SOLICITING FOR A PROSTITUTE'
WHERE description = 'SOLICIT FOR PROSTITUTE';

UPDATE CrimeData_CLean SET description = 'SOLICIT NARCOTICS ON PUBLIC WAY'
WHERE description = 'SOLICIT NARCOTICS ON PUBLICWAY';

UPDATE CrimeData_Clean SET description = 'SELL / ADVERTISE FIREWORKS'
WHERE description = 'SELL/ADVERTISE FIREWORKS';

UPDATE CrimeData_Clean SET description = 'SELL / GIVE / DELIVER LIQUOR TO MINOR'
WHERE description = 'SELL/GIVE/DEL LIQUOR TO MINOR';

UPDATE CrimeData_Clean SET description = 'UNLAWFUL POSSESSION - HANDGUN'
WHERE description = 'UNLAWFUL POSS OF HANDGUN';

UPDATE CrimeData_Clean SET description = 'UNLAWFUL POSSESSION - AMMUNITION'
WHERE description = 'UNLAWFUL POSS AMMUNITION';

UPDATE CrimeData_Clean SET description = 'UNLAWFUL POSSESSION - OTHER FIREARM'
WHERE description = 'UNLAWFUL POSS OTHER FIREARM';

UPDATE CrimeData_Clean SET description = 'UNLAWFUL SALE - DELIVERY OF FIREARM AT SCHOOL'
WHERE description = 'UNLAWFUL SALE/DELIVERY OF FIREARM AT SCHOOL';

UPDATE CrimeData_Clean SET description = 'UNLAWFUL SALE - HANDGUN'
WHERE description = 'UNLAWFUL SALE HANDGUN';

UPDATE CrimeData_Clean SET description = 'UNLAWFUL SALE - OTHER FIREARM'
WHERE description = 'UNLAWFUL SALE OTHER FIREARM';

UPDATE CrimeData_Clean SET description = 'UNLAWFUL USE - HANDGUN'
WHERE description = 'UNLAWFUL USE HANDGUN';

UPDATE Crimedata_Clean SET description = 'UNLAWFUL USE - OTHER DANGEROUS WEAPON'
WHERE description = 'UNLAWFUL USE OTHER DANG WEAPON';

UPDATE CrimeData_Clean SET description = 'UNLAWFUL USE - OTHER FIREARM'
WHERE description = 'UNLAWFUL USE OTHER FIREARM';

UPDATE CrimeData_Clean SET description = 'UNLAWFUL USE / SALE OF AIR RIFLE'
WHERE description = 'UNLAWFUL USE/SALE AIR RIFLE';

UPDATE CrimeData_Clean SET description = 'UNLAWFUL VISITATION INTERFERENCE'
WHERE description = 'UNLAWFUL INTERFERE/VISITATION';

UPDATE CrimeData_Clean SET description = 'VIOLENT OFFENDER - ANNUAL REGISTRATION'
WHERE description = 'VIOLENT OFFENDER: ANNUAL REGISTRATION';

UPDATE CrimeData_Clean SET description = 'VIOLENT OFFENDER - DUTY TO REGISTER'
WHERE description = 'VIOLENT OFFENDER: DUTY TO REGISTER';

UPDATE CrimeData_Clean SET description = 'VIOLENT OFFENDER - FAIL TO REGISTER NEW ADDRESS'
WHERE description = 'VIOLENT OFFENDER: FAIL TO REGISTER NEW ADDRESS';

UPDATE CrimeData_Clean SET description = 'RETAIL THEFT'
WHERE description = 'THEFT RETAIL';

UPDATE CrimeData_Clean SET description = 'VIOLATION OF CHARITABLE GAME ACT'
WHERE description = 'VIOL CHARITABLE GAME ACT';

SELECT description, COUNT(*) AS cnt
FROM CrimeData_Clean
WHERE description REGEXP '^(ABUSE|ANIMAL|ALTER|BOGUS|CHILD|CRIM|DOMESTIC|FINANCIAL|GUN|HARBOR|HUMAN)'
GROUP BY description
ORDER BY description;

UPDATE CrimeData_Clean SET description = 'ABUSE / NEGLECT - CARE FACILITY'
WHERE description = 'ABUSE/NEGLECT: CARE FACILITY';

UPDATE CrimeData_Clean SET description = 'ALTER / FORGE PRESCRIPTION'
WHERE description = 'ALTER/FORGE PRESCRIPTION';

UPDATE Crimedata_Clean SET description = 'ANIMAL ABUSE / NEGLECT'
WHERE description = 'ANIMAL ABUSE/NEGLECT';

UPDATE CrimeData_Clean SET description = 'CHILD ABDUCTION / STRANGER'
WHERE description = 'CHILD ABDUCTION/STRANGER';

UPDATE CrimeData_Clean SET description = 'CRIMINAL SEXUAL ABUSE BY FAMILY MEMBER'
WHERE description = 'CRIM SEX ABUSE BY FAM MEMBER';

UPDATE CrimeData_Clean SET description = 'CRIMINAL SEXUAL ABUSE - SEXUAL PENETRATION'
WHERE description = 'CRIM SEX ABUSE-PENETRATE - OFF < 5 YRS OLDER - VIC 13-16 YOA';

UPDATE CrimeData_Clean SET description = 'FINANCIAL IDENTITY THEFT: OVER $300'
WHERE description = 'FINANCIAL ID THEFT: OVER $300';

UPDATE CrimeData_Clean SET description = 'FINANCIAL IDENTITY THEFT: OVER $300'
WHERE description = 'FINANCIAL IDENTITY THEFT OVER $ 300';

UPDATE CrimeData_Clean SET description = 'FINANCIAL IDENTITY THEFT: $300 & UNDER'
WHERE description = 'FINANCIAL ID THEFT:$300 &UNDER';

UPDATE CrimeData_Clean SET description = 'FINANCIAL IDENTITY THEFT: $300 & UNDER'
WHERE description = 'FINANCIAL IDENTITY THEFT $300 AND UNDER';

UPDATE CrimeData_Clean SET description = 'GUN OFFENDER - ANNUAL REGISTRATION'
WHERE description = 'GUN OFFENDER: ANNUAL REGISTRATION';

UPDATE CrimeData_Clean SET description = 'GUN OFFENDER - DUTY TO REGISTER'
WHERE description ='GUN OFFENDER: DUTY TO REGISTER';

UPDATE Crimedata_Clean SET description = 'GUN OFFENDER - DUTY TO REPORT CHANGE OF INFORMATION'
WHERE description = 'GUN OFFENDER: DUTY TO REPORT CHANGE OF INFORMATION';

SELECT description, COUNT(*) FROM CrimeData_Clean
WHERE description = 'CHILD ABDUCTION/STRANGER';

SELECT description, COUNT(*) AS cnt
FROM CrimeData_Clean
WHERE description REGEXP '^(ARSON|BOMB|BRIB|BURG|COMPEL|COMPUTER|CONCEAL|CONTRA|COUNTERFEIT|CREDIT|CYBER|DEFACE|EMBEZ|EXTORT|FORFEIT|FORG|FRAUD|HOME|INTIMIDAT|KIDNAP|LIQUOR|LOOT|MONEY|OBSCEN|OBSTRUCT|OFFICIAL|PANDERING|PIMPING|PUBLIC|RECKLESS|ROBBERY|STALKING|TRESPASS|WEAPON)'
GROUP BY description
ORDER BY description;

UPDATE CrimeData_Clean SET description = 'ARSONIST - ANNUAL REGISTRATION'
WHERE description = 'ARSONIST: ANNUAL REGISTRATION';

UPDATE CrimeData_Clean SET description = 'ARSONIST - FAIL TO REGISTER NEW ADDRESS'
WHERE description = 'ARSONIST: FAIL TO REGISTER NEW ADDRESS';

UPDATE CrimeData_Clean SET description = 'ARSONIST - DUTY TO REGISTER'
WHERE description = 'ARSONIST: DUTY TO REGISTER';

UPDATE CrimeData_Clean SET description = 'DEFACE IDENTIFICATION MARKS OF FIREARM'
WHERE description = 'DEFACE IDENT MARKS OF FIREARM';

UPDATE CrimeData_Clean SET description = 'PUBLIC AID WIRE/MAIL FRAUD - VIA MAIL/PACKAGE/DELIVERY SYS'
WHERE description = 'PUBLIC AIR WIRE AND MAIL FRAUD - VIA WIRE, RADIO, TELEVISION';

SELECT description, COUNT(*) FROM CrimeData_Clean
WHERE description LIKE 'PUBLIC A%'
GROUP BY description;

SELECT description, COUNT(*) AS cnt
FROM CrimeData_Clean
WHERE description REGEXP '^(AGG|ATT|MANU|POSS|ARMED|STRONG|THEFT|STOLEN|SEX|SELL|SOLICIT|UNLAWFUL|VIOL|ABUSE|ANIMAL|ALTER|CHILD|CRIM|FINANCIAL|GUN|ARSON|DEFACE|PUBLIC)'
  AND description NOT REGEXP '^(AGGRAVATED|ATTEMPT |MANUFACTURE|POSSESS|ARMED -|STRONG ARM|THEFT /|THEFT B|THEFT F|THEFT O|STOLEN P|SEXUAL|SELL /|SOLICITING|SOLICIT N|SOLICIT O|UNLAWFUL P|UNLAWFUL S|UNLAWFUL U|UNLAWFUL V|VIOLATION|VIOLENT O|ABUSE /|ANIMAL A|ALTER /|CHILD A|CRIMINAL|FINANCIAL E|FINANCIAL I|GUN O|ARSON|DEFACE I|PUBLIC A|PUBLIC D|PUBLIC I)'
GROUP BY description
ORDER BY description;

UPDATE CrimeData_Clean SET description = 'ATTEMPT AGGRAVATED CRIMINAL SEXUAL ABUSE'
WHERE description = 'ATT AGG CRIM SEXUAL ABUSE';

UPDATE Crimedata_Clean SET description = 'ATTEMPT AGGRAVATED CRIMINAL SEXUAL ABUSE'
WHERE description = 'ATT AGG CRIMINAL SEXUAL ABUSE';

UPDATE CrimeData_Clean SET description = 'ATTEMPT CRIMINAL SEXUAL ABUSE'
WHERE description = 'ATT CRIM SEXUAL ABUSE';

UPDATE CrimeData_Clean SET description = 'ATTEMPT - AUTOMOBILE'
WHERE description = 'ATT: AUTOMOBILE';

UPDATE CrimeData_Clean SET description = 'ATTEMPT - TRUCK, BUS, MOTOR HOME'
WHERE description = 'ATT: TRUCK, BUS, MOTOR HOME';

Select LocationDescription, COUNT(*) AS CNT 
FROM CrimeData_Clean
GROUP BY LocationDescription
ORDER BY LocationDescription ASC;

UPDATE CrimeData_Clean SET LocationDescription = 'AIRCRAFT'
WHERE LocationDescription = 'AIRPORT/AIRCRAFT';

UPDATE CrimeData_Clean SET LocationDescription = 'BOAT / WATERCRAFT'
WHERE LocationDescription = 'BOAT/WATERCRAFT';

UPDATE CrimeData_Clean SET LocationDescription = 'CHA HALLWAY / STAIRWELL / ELEVATOR'
WHERE LocationDescription = 'CHA HALLWAY/STAIRWELL/ELEVATOR';

UPDATE CrimeData_Clean SET LocationDescription = 'CHA PARKING LOT / GROUNDS'
WHERE LocationDescription = 'CHA PARKING LOT/GROUNDS';

UPDATE CrimeData_Clean SET LocationDescription = 'CHURCH / SYNAGOGUE / PLACE OF WORSHIP'
WHERE LocationDescription = 'CHURCH/SYNAGOGUE/PLACE OF WORSHIP';

UPDATE CrimeData_Clean SET LocationDescription = 'COLLEGE / UNIVERSITY - GROUNDS'
WHERE LocationDescription = 'COLLEGE/UNIVERSITY GROUNDS';

UPDATE CrimeData_Clean SET LocationDescription = 'COLLEGE / UNIVERSITY - RESIDENCE HALL'
WHERE LocationDescription = 'COLLEGE/UNIVERSITY RESIDENCE HALL';

UPDATE CrimeData_Clean SET LocationDescription = 'FACTORY / MANUFACTURING BUILDING'
WHERE LocationDescription = 'FACTORY/MANUFACTURING BUILDING';

UPDATE CrimeData_Clean SET LocationDescription = 'GOVERNMENT BUILDING / PROPERTY'
WHERE LocationDescription = 'GOVERNMENT BUILDING/PROPERTY';

UPDATE CrimeData_Clean SET LocationDescription = 'HIGHWAY / EXPRESSWAY'
Where LocationDescription = 'HIGHWAY/EXPRESSWAY';

UPDATE CrimeData_Clean SET LocationDescription = 'HOSPITAL BUILDING / GROUNDS'
WHERE LocationDescription = 'HOSPITAL BUILDING/GROUNDS';

UPDATE CrimeData_Clean SET LocationDescription = 'HOTEL / MOTEL'
WHERE LocationDescription = 'HOTEL/MOTEL';

UPDATE Crimedata_Clean SET LocationDescription = 'LAKEFRONT / WATERFRONT / RIVERBANK'
WHERE LocationDescription = 'LAKEFRONT/WATERFRONT/RIVERBANK';

UPDATE CrimeData_Clean SET LocationDescription = 'MEDICAL / DENTAL OFFICE'
WHERE LocationDescription = 'MEDICAL/DENTAL OFFICE';

UPDATE CrimeData_Clean SET LocationDescription = 'MOVIE HOUSE / THEATER'
WHERE LocationDescription = 'MOVIE HOUSE/THEATER';

UPDATE Crimedata_Clean SET LocationDescription = 'NURSING / RETIREMENT HOME'
WHERE LocationDescription = 'NURSING HOME/RETIREMENT HOME';

UPDATE CrimeData_Clean SET LocationDescription = 'OTHER'
WHERE LocationDescription = 'OTHER (SPECIFY)';

UPDATE CrimeData_Clean SET LocationDescription = 'OTHER RAILROAD PROPERTY / TRAIN DEPOT'
WHERE LocationDescription = 'OTHER RAILROAD PROP / TRAIN DEPOT';

UPDATE CrimeData_Clean SET LocationDescription = 'PARKING LOT / GARAGE (NON RESIDENTIAL)'
WHERE LocationDescription = 'PARKING LOT/GARAGE(NON.RESID.)';

UPDATE CrimeData_Clean SET LocationDescription = 'POLICE FACILITY / VEHICLE PARKING LOT'
WHERE LocationDescription = 'POLICE FACILITY/VEH PARKING LOT';

UPDATE Crimedata_Clean SET LocationDescription = 'POOL ROOM'
WHERE LocationDescription = 'POOLROOM';

UPDATE CrimeData_Clean SET LocationDescription = 'RESIDENCE - GARAGE'
WHERE LocationDescription = 'RESIDENCE-GARAGE';

UPDATE CrimeData_Clean SET LocationDescription = 'RESIDENCE - PORCH / HALLWAY'
WHERE LocationDescription = 'RESIDENCE PORCH/HALLWAY';

UPDATE CrimeData_Clean SET LocationDescription = 'RESIDENCE - YARD (FRONT / BACK)'
WHERE LocationDescription = 'RESIDENTIAL YARD (FRONT/BACK)';

UPDATE CrimeData_Clean SET LocationDescription = 'SCHOOL - PRIVATE BUILDING'
WHERE LocationDescription = 'SCHOOL, PRIVATE, BUILDING';

UPDATE CrimeData_Clean SET LocationDescription = 'SCHOOL - PRIVATE GROUNDS'
WHERE LocationDescription = 'SCHOOL, PRIVATE, GROUNDS';

UPDATE CrimeData_Clean SET LocationDescription = 'SCHOOL - PUBLIC BUILDING'
WHERE LocationDescription = 'SCHOOL, PUBLIC, BUILDING';

UPDATE CrimeData_Clean SET LocationDescription = 'SCHOOL - PUBLIC GROUNDS'
WHERE LocationDescription = 'SCHOOL, PUBLIC, GROUNDS';

UPDATE CrimeData_Clean SET LocationDescription = 'SPORTS ARENA / STADIUM'
WHERE LocationDescription = 'SPORTS ARENA/STADIUM';

UPDATE CrimeData_Clean SET LocationDescription = 'TAVERN / LIQUOR STORE'
WHERE LocationDescription = 'TAVERN/LIQUOR STORE';

UPDATE Crimedata_Clean SET LocationDescription = 'TAXI CAB'
WHERE LocationDescription = 'TAXICAB';

UPDATE CrimeData_Clean SET LocationDescription = 'VACANT LOT / LAND'
WHERE LocationDescription = 'VACANT LOT/LAND';

UPDATE CrimeData_Clean SET LocationDescription = 'VEHICLE - COMMERCIAL'
WHERE LocationDescription = 'VEHICLE-COMMERCIAL';

UPDATE CrimeData_Clean SET LocationDescription = 'VEHICLE - COMMERCIAL: ENTERTAINMENT / PARTY BUS'
WHERE LocationDescription = 'VEHICLE-COMMERCIAL - ENTERTAINMENT/PARTY BUS';

UPDATE Crimedata_Clean SET LocationDescription = 'VEHICLE - COMMERCIAL: TROLLEY BUS'
WHERE LocationDescription = 'VEHICLE-COMMERCIAL - TROLLEY BUS';

UPDATE CrimeData_Clean SET LocationDescription = 'VEHICLE - OTHER RIDE SHARE SERVICE (LYFT, UBER, ETC.)'
WHERE LocationDescription = 'VEHICLE - OTHER RIDE SHARE SERVICE (E.G., UBER, LYFT)';


UPDATE CrimeData_Clean SET LocationDescription = 'UNKNOWN'
WHERE LocationDescription = '' OR LocationDescription IS NULL;

UPDATE CrimeData_Clean SET LocationDescription = 'NURSING / RETIREMENT HOME'
WHERE LocationDescription = 'NURSING HOME';

UPDATE CrimeData_Clean SET LocationDescription = 'HOTEL / MOTEL'
WHERE LocationDescription = 'MOTEL';

SELECT 
  MIN(latitude), MAX(latitude),
  MIN(longitude), MAX(longitude)
FROM CrimeData_Clean
WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

UPDATE CrimeData_Clean
SET Latitude = null, Longitude = null
WHERE Latitude = 0 OR Longitude = 0
OR Latitude < 41.6 OR Latitude > 42.1
Or Longitude < -87.9 OR Longitude > -87.5;

ALTER TABLE CrimeData_Clean 
	ADD COLUMN Crime_Year INT,
    ADD COLUMN Crime_Month INT,
    ADD COLUMN Crime_Day INT,
    ADD COLUMN Crime_Hour INT,
    ADD COLUMN Day_Of_Week VARCHAR(10);
    
UPDATE CrimeData_Clean SET
	Crime_Year = YEAR(Date),
    Crime_Month = month(Date),
    Crime_Day = Day(Date),
    Crime_Hour = hour(Date),
    Day_Of_Week = dayname(Date);

DROP TABLE CrimeData_Raw;

select DISTINCT arrest
from CrimeData_Clean;

-- Check what values actually exist in the column
SELECT Arrest, COUNT(*) AS cnt
FROM CrimeData_Clean
GROUP BY Arrest;

DESCRIBE CrimeData_Clean;

select DISTINCT domestic 
from CrimeData_Raw;

UPDATE CrimeData_Clean SET  domestic = 1
where domestic = 0 
AND `CaseNumber` in (
Select CaseNumber
From CrimeData_Raw
Where domestic = 'true');

UPDATE CrimeData_Clean SET  arrest = 1
where arrest = 0 
AND `CaseNumber` in (
Select CaseNumber
From CrimeData_Raw
Where arrest = 'true');

Select DISTINCT domestic
From CrimeData_Clean;

select * 
from Crimedata_Clean;

SELECT
  COUNT(*) AS total_rows,
  SUM(CASE WHEN Arrest = 1 THEN 1 ELSE 0 END) AS total_arrests,
  ROUND(SUM(Arrest) / COUNT(*) * 100, 2) AS arrest_rate_pct,
  MIN(Crime_Year) AS first_year,
  MAX(Crime_Year) AS last_year,
  COUNT(DISTINCT PrimaryType) AS unique_crime_types,
  COUNT(DISTINCT LocationDescription) AS unique_locations,
  SUM(CASE WHEN Latitude IS NULL THEN 1 ELSE 0 END) AS null_coords
FROM CrimeData_Clean;

Select DISTINCT description
From Crimedata_Clean
ORDER BY description asc;

UPDATE CrimeData_Clean SET description = 'FAILURE TO MAINTAIN RECORDS - CONTROLLED SUBSTANCES'
Where description = 'CONT SUBS:FAIL TO MAINT RECORD';

UPDATE Crimedata_Clean SET description = 'DELIVER CONTROLLED SUBSTANCES TO PERSON UNDER 18'
Where description = 'DEL CONT SUBS TO PERSON <18';

UPDATE Crimedata_Clean SET description = 'DELIVER CANNABIS TO PERSON UNDER 18'
WHERE description = 'DELIVER CANNABIS TO PERSON <18';

UPDATE CrimeData_Clean SET description = 'DISCLOSE DOMESTIC VIOLENCE VICTIM LOCATION'
Where description = 'DISCLOSE DV VICTIM LOCATION';

UPDATE CrimeData_Clean SET description = 'ENDANGERING LIFE / HEALTH OF CHILD'
Where description = 'ENDANGERING LIFE/HEALTH CHILD';

UPDATE CrimeData_Clean SET description = 'FAILURE TO MAINTAIN RECORDS - CONTROLLED SUBSTANCES'
WHERE description = 'FAIL REGISTER LIC:CONT SUBS';

UPDATE Crimedata_Clean SET description = 'FINANCIAL EXPLOITATION OF AN ELDERLY OR DISABLED PERSON'
Where description = 'FINAN EXPLOIT-ELDERLY/DISABLED';

UPDATE CrimeData_Clean SET description = 'FROM COIN-OPERATED MACHINE OR DEVICE'
Where description = 'FROM COIN-OP MACHINE/DEVICE';

UPDATE CrimeData_Clean SET description = 'GAME / AMUSEMENT DEVICE'
Where description = 'GAME/AMUSEMENT DEVICE';

UPDATE CrimeData_Clean SET description = 'INDECENT SOLICITATION OF A CHILD'
WHERE description = 'INDECENT SOLICITATION/CHILD';

UPDATE CrimeData_Clean SET description = 'INDECENT SOLICITATION OF AN ADULT'
WHERE description = 'INDECENT SOLICITATION/ADULT';

UPDATE CrimeData_Clean SET description = 'INTERFERE WITH EMERGENCY EQUIPMENT'
WHERE description = 'INTERFERE W/ EMERGENCY EQUIP';

UPDATE CrimeData_Clean SET description = 'INTERFERE WITH HIGHER EDUCATION'
WHERE description = 'INTERFERE W/ HIGHER EDUCATION';

UPDATE CrimeData_Clean SET description = 'KEEP PLACE OF PROSTITUTION'
WHERE description = 'KEEPING PLACE OF PROSTITUTION';

UPDATE CrimeData_Clean SET description = 'KEEP PLACE OF JUVENILE PROSTITUTION'
WHERE description = 'KEEP PLACE OF JUV PROSTITUTION';

UPDATE CrimeData_Clean SET description = 'NON-CONSENSUAL DISSEMINATION OF PRIVATE SEXUAL IMAGES'
WHERE description = 'NON-CONSENSUAL DISSEMINATION PRIVATE SEXUAL IMAGES';

UPDATE CrimeData_Clean SET description = 'PUBLIC AID WIRE/MAIL FRAUD - VIA MAIL/PACKAGE/DELIVERY SYS'
WHERE description = 'PBLC AID WIRE AND MAIL FRAUD- UNLAW OBT PBLC AID';

UPDATE CrimeData_Clean SET description = 'POSSESSION - CHEMICAL / DRY-ICE DEVICE'
WHERE description = 'POS: CHEMICAL/DRY-ICE DEVICE';

UPDATE CrimeData_Clean SET description = 'POSSESSION - EXPLOSIVE / INCENDIARY DEVICE'
WHERE description = 'POS: EXPLOSIVE/INCENDIARY DEV';

UPDATE CrimeData_Clean SET description = 'POSSESS - HYPODERMIC NEEDLE'
WHERE description = 'POS: HYPODERMIC NEEDLE';

UPDATE CrimeData_Clean SET description = 'POSSESSION OF PORNOGRAPHIC PRINT'
WHERE description ='POS: PORNOGRAPHIC PRINT';

UPDATE CrimeData_Clean SET description = 'PROTECTED EMPLOYEE - HANDS, FISTS, FEET, NO / MINOR INJURY'
WHERE description = 'PRO EMP HANDS NO/MIN INJURY';

UPDATE CrimeData_Clean SET description = 'PROTECTED EMPLOYEE - HANDS, FISTS, FEET, NO / MINOR INJURY'
WHERE description = 'PROTECTED EMPLOYEE: HANDS NO / MIN INJURY';

UPDATE CrimeData_Clean SET description = 'RESIST / OBSTRUCT / DISARM OFFICER'
WHERE description = 'RESIST/OBSTRUCT/DISARM OFFICER';

UPDATE CrimeData_Clean SET description = 'SALE OF TOBACCO PRODUCTS TO MINOR'
WHERE description = 'SALE TOBACCO PRODUCTS TO MINOR';

UPDATE CrimeData_Clean SET description = 'SALE / DISTRIBUTE OBSCENE MATERIAL TO MINOR'
WHERE description = 'SALE/DIST OBSCENE MAT TO MINOR';

UPDATE CrimeData_Clean SET description = 'SALE / DELIVER - DRUG PARAPHERNALIA'
WHERE description = 'SALE/DEL DRUG PARAPHERNALIA';

UPDATE CrimeData_Clean SET description =  'SALE / DELIVER - HYPODERMIC NEEDLE'
WHERE description = 'SALE/DEL HYPODERMIC NEEDLE';

UPDATE CrimeData_Clean SET description = 'VEHICLE TITLE / REGISTRATION OFFENSE'
WHERE description = 'VEHICLE TITLE/REG OFFENSE';

UPDATE CrimeData_Clean SET description = 'VIOLATION OF BAIL BOND - DOMESTIC VIOLENCE'
WHERE description = 'VIO BAIL BOND: DOM VIOLENCE';

UPDATE CrimeData_Clean SET description = 'OTHER ARSON / EXPLOSIVE INCIDENT'
WHERE description = 'OTHER ARSON/EXPLOSIVE INCIDENT';

UPDATE CrimeData_Clean SET description = 'SEX OFFENDER - FAIL TO REGISTER NEW ADDRESS'
WHERE description = 'SEX OFFENDER: FAIL REG NEW ADD';

UPDATE CrimeData_Clean SET description = 'TO STATE SUPPORTED PROPERTY'
WHERE description = 'TO STATE SUP PROP';

UPDATE CrimeData_Clean SET description = 'TO STATE SUPPORTED PROPERTY'
WHERE description = 'TO STATE SUP LAND';

UPDATE CrimeData_Clean SET description = 'CONTRIBUTE TO THE DELINQUENCY OF CHILD'
WHERE description = 'CONTRIBUTE DELINQUENCY OF A CHILD';

UPDATE CrimeData_Clean SET description = 'CONTRIBUTE TO THE DELINQUENCY OF CHILD'
WHERE description = 'CONTRIBUTE CRIM DELINQUENCY JUVENILE';

UPDATE CrimeData_Clean SET description = 'CONTRIBUTE TO THE DELINQUENCY OF CHILD'
WHERE description = 'CONTRIBUTE TO THE CRIMINAL DELINQUENCY OF CHILD';

UPDATE CrimeData_Clean SET description = 'CYCLE, SCOOTER, BIKE WITH VIN'
WHERE description = 'CYCLE, SCOOTER, BIKE W-VIN';

UPDATE CrimeData_Clean SET description = 'FALSE / STOLEN / ALTERED TRP'
WHERE description = 'FALSE/STOLEN/ALTERED TRP';

UPDATE CrimeData_Clean SET description = 'OF AN UNBORN CHILD'
WHERE description = 'OF UNBORN CHILD';

SELECT 	
	Crime_Year,
    PrimaryType,
    COUNT(*) AS Total_Crime,
    SUM(CASE WHEN Arrest = 1 then 1 else 0 END) AS Total_Arrest
FROM CrimeData_Clean
GROUP BY Crime_Year, PrimaryType;

SELECT 
  Crime_Hour,
  Day_Of_Week,
  COUNT(*) AS Total_Crime
FROM CrimeData_Clean
GROUP BY Crime_Hour, Day_Of_Week;

Select
	LocationDescription,
    COUNT(*) AS Total_Crime,
    SUM(Arrest) AS Total_Arrest
FROM CrimeData_Clean
GROUP BY LocationDescription;
    
SELECT
	District,
    Crime_Year,
    COUNT(*) AS Total_Crime
From CrimeData_Clean
Group By District, Crime_Year;

SELECT
	Crime_Month,
    Crime_Year,
    COUNT(*) AS Total_Crime
From CrimeData_Clean 
GROUP BY Crime_Month, Crime_Year;






















































































































































































