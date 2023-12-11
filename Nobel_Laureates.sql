--The SQL flavour used for this project is PostgreSQL

--Creating a table for the Nobel Laureates dataset
CREATE TABLE nobel_laureates (
	year_of_award SMALLINT, 
	category VARCHAR(20),
	motivation VARCHAR(380),
	prize_share SMALLINT,
	laureate_id SMALLINT,
	full_name VARCHAR(60),
	gender VARCHAR(10),
	born VARCHAR(10),
	born_country VARCHAR(40),
	born_city VARCHAR(30),
	died VARCHAR(10),
	died_country VARCHAR(20),
	died_city VARCHAR(30),
	organization_name VARCHAR(110),
	organization_country VARCHAR(20),
	organization_city VARCHAR(30)
	)


--After importing the dataset using PostgreSQL, it is time to view the data
SELECT *
FROM nobel_laureates
LIMIT 10;

----------------------------------------------------------------------------------------------------------------------
--Below are the different analysis performed to extract information 

--(A)Basic Information:

--(1) Retrieve the total number of awards.
WITH count_yearly_awards AS (SELECT 
			 		year_of_award, 
			 		COUNT(DISTINCT category) AS number_of_count
			FROM 
			 		nobel_laureates
			GROUP BY 
			 		year_of_award
			)

SELECT 
	SUM(number_of_count) AS total_awards
FROM count_yearly_awards;


--(2)Retrieve the number of Nobel Laureates by gender with the total number of Laureates.
SELECT 
		gender, 
	    COUNT(full_name) AS number_of_laureates
FROM 
		nobel_laureates
GROUP BY 
		CUBE(gender)
ORDER BY 
		COUNT(full_name) ASC;
--Note that org in the gender column represents organization. 

--(3)List the distinct categories (e.g., physics, chemistry, peace) of Nobel Prizes.

SELECT 
		DISTINCT(category) AS nobel_prize_category
FROM 
		nobel_laureates;


----------------------------------------------------------------------------------------------------------------------
-- (B)Time-based Analysis:

--(4)Identify the laureate(s) who received the earliest Nobel Prize.
SELECT 
		full_name AS name_of_laureate,
	   	category AS prize_category
FROM 
		nobel_laureates
WHERE 
		year_of_award = '1901';--1901 was the first year the nobel prize was awarded.

--(5)Identify the laureate(s) who received the latest Nobel Prize.
SELECT 
		full_name AS name_of_laureate,
	   	category AS prize_category
FROM 
		nobel_laureates
WHERE 
		year_of_award = '2023'
ORDER BY 
		category ASC;

--(6)Supply the number of years in which the number of prize categories given ranges from one to six.
WITH cte AS (
			SELECT 	count_distinct_nobel_prize_category, 
			 		COUNT(year_of_award) AS number_of_years,
					CASE WHEN count_distinct_nobel_prize_category = 6 THEN 'six nobel prizes category'
					WHEN count_distinct_nobel_prize_category = 5 THEN 'five nobel prizes category'
					WHEN count_distinct_nobel_prize_category = 4 THEN 'four nobel prizes category'
					WHEN count_distinct_nobel_prize_category = 3 THEN 'three nobel prizes category'
					WHEN count_distinct_nobel_prize_category = 2 THEN 'two nobel prizes category'
					ELSE 'one nobel prize category' 
					END AS number_prize_category
			  FROM ( 
				  	SELECT year_of_award, 
				  			COUNT(DISTINCT category) AS count_distinct_nobel_prize_category
					FROM 
				  			nobel_laureates
				    GROUP BY 
				  			year_of_award 
			  		) AS subquery
			  GROUP BY 
					count_distinct_nobel_prize_category
			 )
			
SELECT 
		number_prize_category,
	   	number_of_years
FROM 
		cte
ORDER BY number_of_years DESC;

/* 	Summing up the years in the result of the query above add up to 120. But this ought to be 123 years total.
This can be gotten by calculating the sum of the years from 1901 to 2023. 
What then could be the missing years(i.e.,the years the prize was not awarded).
The next question answers this*/

--(7) Get the number of years in which no Nobel Prize was awarded at all.
WITH all_years AS (
					SELECT 
							generate_series(1, 123) AS created_id,
							generate_series(1901,2023) AS created_years
					),

	given_year AS (
					SELECT 
							DISTINCT year_of_award AS distinct_years
					FROM 
							nobel_laureates
					ORDER BY 
							year_of_award ASC
					)

SELECT 
		created_years AS year_with_no_awards
FROM 
		all_years
LEFT JOIN
		given_year
ON 
		all_years.created_years = given_year.distinct_years
WHERE 
		distinct_years IS NULL;


----------------------------------------------------------------------------------------------------------------------
--(C) Prize category-based Analysis:

--(8)Determine the Nobel Prize category with the number of laureates from highest to lowest.
SELECT 
		category AS prize_category,
		COUNT(full_name) AS number_of_laureates
FROM 
		nobel_laureates
GROUP BY 
		category
ORDER BY 
		COUNT(full_name) DESC;

	   

--(9)Find out which category has the highest average age for the deceased laureates.

/* NOTE: To perform this, the born and died column which represents date of birth and date of death repectively 
have to be changed from varying character(VARCHAR)to date data type with the wanted format. The code below will be used*/

-- Starting with born column
ALTER TABLE nobel_laureates
ALTER COLUMN born type date
USING to_date(born, 'YYYY:MM:DD');

--Next to the died column
ALTER TABLE nobel_laureates
ALTER COLUMN died type date
USING to_date(died, 'YYYY:MM:DD');

--Now,back to the question to be answered
WITH date_diff_added AS (
							SELECT 
									*,
		 							EXTRACT(YEAR FROM AGE(died, born)) AS date_difference_in_years
    						FROM 
									nobel_laureates
							WHERE 
									died IS NOT NULL AND died != '0001-01-01' --This date row is excluded because it represents the date in which the date of death of the laureates was unknown/not recorded/not dead yet. 
							ORDER BY 
									EXTRACT(YEAR FROM AGE(died, born)) DESC
						),
	
	average_date_diff_in_years AS (
							SELECT 
									category, 
							 		AVG(date_difference_in_years) AS avg_of_years_diff
							FROM 
									date_diff_added
							GROUP BY 
									category)
SELECT 
		category AS prize_category,
	   	ROUND(avg_of_years_diff,1) AS highest_average_age
FROM 
		average_date_diff_in_years
ORDER BY 
		ROUND(avg_of_years_diff,1) DESC
LIMIT 1;


----------------------------------------------------------------------------------------------------------------------

--(D)Country-based Analysis:

--(10)List the top 10 countries with the most Nobel laureates.
SELECT 
		born_country AS country, --This was calculated based on the country the laureates were born.
		COUNT(*) AS number_of_laureates,
		RANK() OVER (ORDER BY COUNT(*) DESC) --use rank function here
FROM 
		nobel_laureates 
WHERE gender != 'org'
GROUP BY
		born_country
LIMIT 10;

----------------------------------------------------------------------------------------------------------------------

--(E)Gender-based Analysis:

--(11)Calculate the percentage of Nobel Prizes awarded to males, females, and organizations.
SELECT 
		gender,
		percentage
FROM (
		SELECT gender, 
				COUNT(DISTINCT full_name) AS count_of_laureates,
	   			CEILING(( COUNT(full_name)/1000.0)*100) AS percentage
	  FROM 
				nobel_laureates
	  GROUP BY 
				gender
	  ORDER BY
				CEILING(( COUNT(full_name)/1000.0)*100) ASC
	) AS subquery;

--(12)Identify the first three categories with the highest number of female laureates.
SELECT 
		category AS prize_category, 
		COUNT(full_name) AS number_female_laureates
FROM 
		nobel_laureates
WHERE gender= 'female'
GROUP BY 
		category
ORDER BY
		COUNT(full_name) DESC 
LIMIT 3;

----------------------------------------------------------------------------------------------------------------------

--(F)Age-based Analysis:
--Note: All the analysis in this section are performed based on the year of birth and year of award of the laureate.

--(13)Determine the average age of Nobel laureates.
SELECT 
		CEILING(AVG(age_of_laureate)) AS average_age_of_laureate
FROM (
		SELECT *,
				year_of_award - EXTRACT(YEAR FROM born) AS age_of_laureate
	  	FROM
				nobel_laureates ) AS subquery;
				
				
--(14) Obtain the age and other relevant information about the youngest Nobel Laureate. 
SELECT 
		full_name AS youngest_laureate,
		category,
		year_of_award,
		born, 
		age_of_laureate
FROM (
		SELECT *,
				year_of_award - EXTRACT(YEAR FROM born) AS age_of_laureate
	  	FROM
				nobel_laureates
	) AS subquery
WHERE gender != 'org'
GROUP BY 
		full_name, 
		category,
		year_of_award,
		born, 
		age_of_laureate
ORDER BY 
		age_of_laureate ASC
LIMIT 1;


--(15) Obtain the age and other relevant information about the oldest Nobel Laureate.
SELECT
		full_name AS oldest_laureate, 
		category,
		year_of_award,
		born, 
		age_of_laureate
FROM (
		SELECT *,
				year_of_award - EXTRACT(YEAR FROM born) AS age_of_laureate
	  	FROM
				nobel_laureates
	) AS subquery
WHERE gender != 'org'
GROUP BY 
		full_name, 
		category,
		year_of_award,
		born, 
		age_of_laureate
ORDER BY 
		age_of_laureate DESC
LIMIT 1;

--(16) Calculate the average age of Nobel laureates for each category and present the result alongside the category names.
SELECT 
		category AS prize_category,
		CEILING(AVG(age_of_laureate)) AS average_age
FROM (
		SELECT *,
				year_of_award - EXTRACT(YEAR FROM born) AS age_of_laureate
	  FROM 
			nobel_laureates
	) AS subquery
GROUP BY category;
----------------------------------------------------------------------------------------------------------------------

--(G)Multiple Prize Winners:

--(17)Identify the laureate(s) who have won Nobel Prizes in multiple prize categories.
SELECT 
		full_name AS name_of_laureate
FROM 
		nobel_laureates
GROUP BY 
		full_name
HAVING COUNT(DISTINCT category) > 1;

--(18)Identify the laureate(s) who have received more than one Nobel Prize.
SELECT 
		full_name AS name_of_laureate
FROM 
		nobel_laureates
GROUP BY 
		full_name
HAVING COUNT(category) > 1;


--(19)Identify the laureate(s) with the multiple prize award in each category.
WITH distinct_laureate_award_count AS (
				SELECT 
						DISTINCT full_name,
						category AS prize_category, 
						COUNT(category) AS count_of_nobel_prize
				FROM 
						nobel_laureates
				GROUP BY 
						DISTINCT full_name,
						category
			)

SELECT 
		DISTINCT full_name AS name_of_laureate,
		prize_category,
		count_of_nobel_prize
FROM 
		distinct_laureate_award_count
WHERE 
		count_of_nobel_prize > '1'
ORDER BY 
		prize_category ASC;

----------------------------------------------------------------------------------------------------------------------

--(H)University-based Analysis:

--(20) Determine which university has produced the most Nobel laureates.
 --This is based on the laureates whose organization's name were provided in the datasets
SELECT 
		organization_name AS name_of_organization, 
		COUNT(full_name) AS number_of_laureate
FROM 
		nobel_laureates
WHERE organization_name IS NOT NULL 
GROUP BY 
		organization_name
ORDER BY 
		COUNT(full_name) DESC
LIMIT 10;

--(21)Identify laureates who were affiliated with multiple universities.
SELECT 
		full_name AS name_of_laureate
FROM 
		nobel_laureates
GROUP BY 
		full_name
HAVING COUNT(DISTINCT organization_name) > 1;


----------------------------------------------------------------------------------------------------------------------
--(I) Pattern Matching:

--(22) Identify the number of laureates who were born and died in different countries.
WITH born_died_country_info AS (
			SELECT *, 
					CASE WHEN born_country = died_country THEN 'yes' 
						ELSE 'no' 
						END AS country_birth_death
			FROM 
					nobel_laureates
			)
SELECT 
		COUNT(*) AS count_laureate_born_died_diff_country
FROM 
		born_died_country_info 
WHERE country_birth_death = 'no' AND died_country IS NOT NULL;

--(23)Identify the number of laureates who were born and died in the same country.
WITH born_died_country_info AS (
			SELECT *, 
					CASE WHEN born_country = died_country THEN 'yes' 
						ELSE 'no' 
					END AS country_birth_death
			FROM 
				nobel_laureates)
SELECT 
		COUNT(*) AS laureate_born_died_same_country
FROM 
		born_died_country_info
WHERE country_birth_death = 'yes' AND died_country IS NOT NULL;


--(24)  Identify Nobel laureates who are part of the same family or are siblings.
WITH pattern AS (
				SELECT 
						year_of_award, 
			 			category,
			 			laureate_id,
			 			full_name,
   						SUBSTRING(full_name FROM 1 FOR POSITION(' ' IN full_name) - 1) AS first_name,
    					SUBSTRING(full_name FROM POSITION(' ' IN full_name) + 1) AS last_name,
			 			gender,
						born,
						born_country, 
						born_city, 
						died,
						organization_name
			 FROM 
					nobel_laureates
			 WHERE gender != 'org'
			)

SELECT year_of_award,
	   category,
	   first_name,
	   last_name,
	   gender,
	   born,
	   organization_name
FROM 
		pattern
WHERE last_name IN ('Curie','Joliot-Curie', 'Joliot', 'Cori','Moser', 'I. Moser','Myrdal', 'Bragg', 'Bohr','N. Bohr', 
					'Von Euler','von Euler-Chelpin', 'Kornberg','D. Kornberg', 'Siegbahn','M. Siegbahn', 'Thomson', 
					'Paget Thomson', 'Tinbergen', 'Duflo',
				    'Banerjee', 'Paebo', 'K. Bergstrom'
				   )   --These are names I got from the nobel Prize website about Laureates who are related. Some couples, siblings, etc
ORDER BY 
		last_name ASC;



----------------------------------------------------------------------------------------------------------------------
--(Q)Mortality rate analysis:

--(25)Provide the percentage of the deceased laureates.(Note:This calculation is based on the dataset used in this case study)
WITH died_is_null AS (
						SELECT 
								COUNT(laureate_id) AS first_count
						FROM 
								nobel_laureates
						WHERE died IS NULL
					),

  	died_is_out_of_format AS (
	 					SELECT 
								COUNT(laureate_id) AS second_count
						FROM 
								nobel_laureates
						WHERE died = '0001-01-01'
  					)
  
SELECT 
		100 - CEILING(((SELECT 
				  		first_count 
				  FROM 
				  		died_is_null
				 ) + 
				(SELECT 
		 				second_count 
				 FROM 
				 		died_is_out_of_format))/1000.0 * 100) AS percentage_of_deceased_laureates


-- END OF PROJECT