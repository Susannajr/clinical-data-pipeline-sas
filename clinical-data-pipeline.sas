/*====================================================*/
/* Project: Automating Clinical Data Pipeline         */
/* CDISC-Compliant ETL and Macro Validation Framework */
/*====================================================*/


/*----------------------------------------------------*/
/* 1. Import raw datasets                             */
/*----------------------------------------------------*/

proc import datafile="/home/u64502601/Diploma/DM.xlsx"
out=work.dm
dbms=xlsx
replace;
sheet="sheet1";
range="G3:J14";
getnames=yes;
run;

proc import datafile="/home/u64502601/Diploma/VS.xlsx"
out=work.vs
dbms=xlsx
replace;
sheet="sheet1";
range="D5:K16";
getnames=yes;
run;


/*----------------------------------------------------*/
/* 2. Remove duplicate patient records                */
/*----------------------------------------------------*/

proc sort data=dm nodupkey;
by USUBJID;
run;

proc sort data=vs nodupkey;
by USUBJID VISITNUM;
run;


/*----------------------------------------------------*/
/* 3. Metadata quality checks                         */
/*----------------------------------------------------*/

data dm_clean;
set dm;

/* Missing ID check */
if missing(USUBJID) then delete;

/* Age range check */
if AGE<18 or AGE>100 then do;
FLAG="AGE_ERROR";
end;
run;


/*----------------------------------------------------*/
/* 4. Clinical anomaly detection                      */
/*----------------------------------------------------*/

data vs_clean;
set vs;

/* Temperature */
if TEMP<35 or TEMP>42 then TEMP_FLAG="ABNORMAL";

/* Heart rate */
if HR<40 or HR>180 then HR_FLAG="ABNORMAL";

/* Weight */
if WEIGHT<30 or WEIGHT>250 then WT_FLAG="ABNORMAL";
run;


/*----------------------------------------------------*/
/* 5. Convert wide structure to long structure        */
/* Arrays + loops                                     */
/*----------------------------------------------------*/

data visits_long;
set vs_clean;

array visit[3] visit1-visit3;
do VISITNUM=1 to 3;
RESULT=visit[VISITNUM];
output;
end;

keep USUBJID VISITNUM RESULT TEMP HR WEIGHT;
run;


/*----------------------------------------------------*/
/* 6. Sort before merge                               */
/*----------------------------------------------------*/

proc sort data=dm_clean;
by USUBJID;
run;

proc sort data=visits_long;
by USUBJID;
run;


/*----------------------------------------------------*/
/* 7. Merge datasets                                  */
/*----------------------------------------------------*/

data final_data;
merge dm_clean(in=a)
      visits_long(in=b);

by USUBJID;

if a and b;

label
USUBJID = "Unique Subject Identifier"
NAME = "Patient Name"
AGE = "Patient Age"
SEX = "Patient Sex"
VISITNUM = "Visit Number"
RESULT = "Visit Result"
TEMP = "Body Temperature"
HR = "Heart Rate"
WEIGHT = "Patient Weight"
FLAG = "Age Validation Flag"
TEMP_FLAG = "Temperature Anomaly Flag"
HR_FLAG = "Heart Rate Anomaly Flag"
WT_FLAG = "Weight Anomaly Flag"
AGEGR = "Age Group";
run;


/*----------------------------------------------------*/
/* 8. Age group derivation                            */
/*----------------------------------------------------*/

proc format;

value agegrp
low-34='Young'
35-60='Middle'
61-high='Senior';
run;


data final_data;
set final_data;

agegr=put(age,agegrp.);
run;


/*----------------------------------------------------*/
/* 9. Reusable Macro framework                        */
/*----------------------------------------------------*/

%macro check(ds,var,low,high);

data &ds;
set &ds;

if &var<&low or &var>&high
then FLAG_&var="ERROR";
run;

%mend;

/* Run macro */

%check(final_data,WEIGHT,30,250);
%check(final_data,TEMP,35,42);
%check(final_data,HR,40,180);


/*----------------------------------------------------*/
/* 10. Automated dataset information                  */
/*----------------------------------------------------*/

proc contents data=final_data;
run;


/*----------------------------------------------------*/
/* 11. Automated log validation                       */
/*----------------------------------------------------*/

filename logfile
"/home/u64502601/sasuser.v94/projectlog.txt";

proc printto log=logfile;
run;

/* rerun code here */
/* return log */

proc printto;
run;


/*----------------------------------------------------*/
/* 12. Final output                                   */
/*----------------------------------------------------*/

proc print data=final_data(obs=20);
run;


/*----------------------------------------------------*/
/* 13. Exporting the result as CSV file.              */
/*----------------------------------------------------*/

proc export data=final_data
outfile="/home/u64502601/Diploma/final.csv"
dbms=csv
replace;
run;
