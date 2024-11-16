------------------------------------------------- Importing Company Metadata file 

create table comp_meta (

	companyId varchar(26),
	industry varchar(36),
	timezone varchar(28)
)

COPY comp_meta (companyId, industry, timezone)  
FROM 'C:\Program Files\PostgreSQL\17\data\HF_data\companyMetadata.csv'
DELIMITER ','
CSV HEADER;



alter table comp_meta
alter column industry type varchar(56)

alter table comp_meta
alter column timezone type varchar(30)

-- The varchar columns above were originally too long for the max length that I set. 

-------------------------------------------------- Importing employee data file 

create table emps ( 
	companyId varchar(26),
	employeeId int,
	gender varchar(10),
	hiringDate timestamp,
	birthDate timestamp,
	deleted varchar(8),
	deletionDate timestamp
)

COPY emps (companyId,
	employeeId,
	gender,
	hiringDate,
	birthDate,
	deleted,
	deletionDate)
FROM 'C:\Program Files\PostgreSQL\17\data\HF_data\employees.csv'
DELIMITER ','
CSV HEADER;

---------------------------Looks like there's some missing values in here, so I'm going to see how many 

select * from emps 

select * from emps where gender is not null 

select distinct(gender), count(gender) from emps group by gender

--- Interestingly the genders are coded in multiple languages: Spanish and what appears to be Catalan. Including country of origin would add some interesting depth to the reporting but aside from the timezone the only other potential geographic indicator are these gender codes which isn't much to run with. I'm going to update them to just 'Male' and 'Female'.



update emps
set gender = 'Female'
where gender = 'Femení' or gender = 'Femenino';

update emps
set gender = 'Male'
where gender = 'Hombre' or gender = 'Mujer' or gender = 'Masculino';




-------------------------------------------------- Importing score_metadata file 

create table score_meta (
	scoreId varchar(26),
	dimension varchar(16),
	dim_id varchar(16),
	subdim varchar(18),
	questionId varchar(26),
	question varchar(150)
)


alter table score_meta
alter column dimension type varchar(36)

copy score_meta (
	scoreId,
	dimension,
	dim_id,
	subdim,
	questionId,
	question
)
FROM 'C:\Program Files\PostgreSQL\17\data\HF_data\scoreMetadata.csv'
DELIMITER ','
CSV HEADER;

--------------------------------------------------Importing scores table
create table score_votes (
	companyId varchar(26),
	employeeId int,
	departmentId varchar(30),
	scoreId varchar(26),
	dim_id varchar(30),
	questionId varchar(26),
	date timestamp,
	scoreVote int
)


alter table score_votes
rename column date to score_votes_date

----Reformatting the "Hiringdate" and "Birthdate" into integers

ALTER TABLE emps
ADD COLUMN age INTEGER; -- Exclude the NOT NULL constraint here

UPDATE emps SET age=(2024-(extract(year from Birthdate)));

ALTER TABLE emps
ADD COLUMN tenure INTEGER;

UPDATE emps SET tenure = (2024-(extract(year from Hiringdate)));

-----Now that I have all my tables pulled in, I can pull what I need from each using a JOIN statement to combine into one. 

alter table emps
add primary key(companyid, employeeid) 


create table nd as 
select emps.companyid, emps.employeeid, emps.gender, comp_meta.industry
from emps
inner join comp_meta
on emps.companyid = comp_meta.companyid


create table nd2 as
select nd.*, score_votes.scoreid, score_votes.dim_id, score_votes.questionid, score_votes.score_votes_date, score_votes.scorevote
from nd
inner join score_votes
on nd.companyid = score_votes.companyid and nd.employeeid = score_votes.employeeid


-------Adding in age and tenure using "birthdate" and "hiringdate", respectively 


select nd2.*, emps.birthdate, emps.hiringdate
from nd2
join emps
on emps.employeeid = nd2.employeeid and emps.companyid = nd2.companyid

alter table nd2 add column birthdate date;
set birthdate = nd2.birthdate 
from nd2 inner join emps on nd2.employeeid = emps.employeeid and nd2.companyid = emps.companyid;

alter table nd2 add column hiringdate date;
set hiredate = nd2.hiringdate 
from nd2 inner join emps on nd2.employeeid = emps.employeeid and nd2.companyid = emps.companyid;

----- Admittedly, I probably did this in a roundabout way; I was indecisive about including the age and tenure variables because of all the missing values.
----- I added them back in, but the file was too large to add to tableau public, so I ended up using both the "new_data" and "emps" tables. 

create table new_data as 
select nd2.companyid, nd2.employeeid, nd2.gender, nd2.industry, nd2.score_votes_date, nd2.scorevote, score_meta.dimension, score_meta.subdim, score_meta.question
from nd2
inner join score_meta
on nd2.scoreid = score_meta.scoreid and nd2.dim_id = score_meta.dim_id and nd2.questionid = score_meta.questionid
